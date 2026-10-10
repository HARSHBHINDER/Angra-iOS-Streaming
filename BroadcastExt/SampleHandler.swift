import CoreImage
import HaishinKit
import ImageIO
import ReplayKit
import RTMPHaishinKit
import VideoToolbox

/// Runs in the ReplayKit broadcast upload extension: a separate process with a ~50 MB memory ceiling.
/// Every screen frame is composited onto the channel's real stream canvas (scene layout + overlay) by
/// [Compositor], then handed to HaishinKit in passthrough mode. Session wiring mirrors HaishinKit's
/// official Examples/iOS/Screencast handler.
final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private var session: (any Session)?
    private var mixer = MediaMixer(captureSessionMode: .manual, multiTrackAudioMixingEnabled: true)
    private var needVideoConfiguration = true
    private let compositor = Compositor()
    private let lock = NSLock()
    private var dest: Destination?
    private var prefs = Prefs()
    private var micMuted = false        // live controls from the Live Activity
    private var screenHidden = false
    private var reload: Task<Void, Never>?

    /// Reads the active channel straight from the shared group so the extension needs no app-only code.
    private static func activeDestination() -> Destination? {
        guard let d = UserDefaults(suiteName: appGroup) else { return nil }
        guard let data = d.data(forKey: "destinations"),
              let list = try? JSONDecoder().decode([Destination].self, from: data) else { return nil }
        let activeId = d.string(forKey: "activeId")
        return list.first { $0.id == activeId } ?? list.first
    }

    override init() {
        super.init()
        Task { await SessionBuilderFactory.shared.register(RTMPSessionFactory()) }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        guard let dest = Self.activeDestination(), let url = URL(string: dest.endpoint) else {
            finishBroadcastWithError(NSError(domain: "LivePipe", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: "Add a channel in the app first."]))
            return
        }
        let startPrefs = Store.prefs
        Store.micMuted = false; Store.screenHidden = false; Store.stopRequested = false
        lock.withLock { self.dest = dest; self.prefs = startPrefs }
        Task {
            do {
                session = try await SessionBuilderFactory.shared.make(url).build()
                // ReplayKit is memory-sensitive: cap the video queue (HaishinKit's own sample uses 5).
                var video = await mixer.videoMixerSettings
                video.mode = .passthrough
                await session?.stream.setVideoInputBufferCounts(5)
                await mixer.setVideoMixerSettings(video)
                await applyVolumes(startPrefs)
                await mixer.startRunning()
                if let session {
                    await mixer.addOutput(session.stream)
                    try await session.connect {}
                }
            } catch {
                finishBroadcastWithError(error)
            }
        }
        // Live edits from the app (scene editor, mixer) arrive through the shared group; poll once a second.
        reload = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self?.reloadLive()
            }
        }
    }

    override func broadcastFinished() {
        reload?.cancel()
        Task {
            await mixer.stopRunning()
            try? await session?.close()
        }
    }

    /// Picks up layout and volume changes; the canvas size stays fixed for the whole broadcast.
    private func reloadLive() async {
        if Store.stopRequested {
            Store.stopRequested = false
            finishBroadcastWithError(NSError(domain: "LivePipe", code: 2,
                                             userInfo: [NSLocalizedDescriptionKey: "Stream ended."]))
            return
        }
        let muted = Store.micMuted, hidden = Store.screenHidden
        lock.withLock { micMuted = muted; screenHidden = hidden }
        let p = Store.prefs
        let changed = lock.withLock { () -> Bool in
            defer { prefs = p }
            return p != prefs
        }
        if changed { await applyVolumes(p) }
        guard var d = Self.activeDestination() else { return }
        lock.withLock {
            guard let cur = dest, cur.id == d.id else { return }
            d.width = cur.width; d.height = cur.height; d.portrait = cur.portrait
            dest = d
        }
    }

    /// Audio mixer: track 0 = microphone, track 1 = app/game audio.
    private func applyVolumes(_ p: Prefs) async {
        var a = await mixer.audioMixerSettings
        a.tracks[0] = AudioMixerTrackSettings(volume: Float(p.micVolume))
        a.tracks[1] = AudioMixerTrackSettings(volume: Float(p.gameVolume))
        await mixer.setAudioMixerSettings(a)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        let (dest, prefs, micMuted, screenHidden) = lock.withLock { (self.dest, self.prefs, self.micMuted, self.screenHidden) }
        switch sampleBufferType {
        case .video:
            guard let dest, let pixels = sampleBuffer.imageBuffer else { return }
            // ReplayKit delivers the native-orientation buffer plus a rotation hint for landscape games.
            let raw = (CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString,
                                       attachmentModeOut: nil) as? NSNumber)?.uint32Value
            let orientation = raw.flatMap { CGImagePropertyOrientation(rawValue: $0) } ?? .up
            guard let frame = compositor.render(pixels, orientation: orientation, dest: dest, hidden: screenHidden,
                                                pts: sampleBuffer.presentationTimeStamp) else { return }
            if needVideoConfiguration {
                needVideoConfiguration = false
                Task {
                    var settings = await session?.stream.videoSettings
                    settings?.videoSize = dest.canvas
                    // HaishinKit 2.2 picks the codec from profileLevel: an HEVC profile switches format to HEVC.
                    settings?.profileLevel = (dest.hevc ? kVTProfileLevel_HEVC_Main_AutoLevel
                                                        : kVTProfileLevel_H264_Baseline_AutoLevel) as String
                    settings?.bitRate = dest.videoBitrate
                    settings?.maxKeyFrameIntervalDuration = Int32(dest.keyframeSeconds)
                    if let settings { try? await session?.stream.setVideoSettings(settings) }
                }
            }
            Task { await mixer.append(frame) }
        case .audioMic:
            if prefs.audioSource != 1, !micMuted, sampleBuffer.dataReadiness == .ready {   // skip mic when "game only" or muted
                Task { await mixer.append(sampleBuffer, track: 0) }
            }
        case .audioApp:
            if prefs.audioSource != 0, sampleBuffer.dataReadiness == .ready {   // skip app when "mic only"
                Task { await mixer.append(sampleBuffer, track: 1) }
            }
        @unknown default:
            break
        }
    }
}

/// Places the screen and overlay on the stream canvas using the same ScreenView math as the editor.
/// Renders on the GPU into a reused 4:2:0 pixel buffer (half the memory of BGRA — the extension is capped).
private final class Compositor {
    private let ctx = CIContext(options: [.cacheIntermediates: false])
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    private var overlayFile = ""
    private var overlay: CIImage?
    private var anim: CGImageSource?            // animated overlay (GIF): one frame decoded at a time
    private var delays: [Double] = []
    private var frameIndex = -1

    /// `hidden` = privacy mode: viewers get a black frame (audio keeps going).
    func render(_ src: CVPixelBuffer, orientation: CGImagePropertyOrientation, dest: Destination, hidden: Bool,
                pts: CMTime) -> CMSampleBuffer? {
        let size = dest.canvas
        let W = size.width, H = size.height
        if poolSize != size { pool = Self.makePool(size); poolSize = size }
        if overlayFile != dest.overlayFile {
            overlayFile = dest.overlayFile; overlay = nil; anim = nil; frameIndex = -1
            if let url = Store.overlayURL(dest.overlayFile), let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
                if CGImageSourceGetCount(src) > 1 { anim = src; delays = AnimatedImage.delays(src) }
                else { overlay = AnimatedImage.image(src, 0, maxPixels: 1920).map { CIImage(cgImage: $0) } }
            }
        }
        // Decode only when the GIF frame changes (GIFs run at ~10-25 fps, the stream at 30-60).
        if let anim {
            let i = AnimatedImage.frame(at: pts.seconds, delays: delays)
            if i != frameIndex { frameIndex = i; overlay = AnimatedImage.image(anim, i, maxPixels: 960).map { CIImage(cgImage: $0) } }
        }

        var screen = CIImage(cvPixelBuffer: src).oriented(orientation)
        screen = screen.transformed(by: CGAffineTransform(translationX: -screen.extent.minX, y: -screen.extent.minY))
        let sw = screen.extent.width, sh = screen.extent.height
        guard sw > 0, sh > 0 else { return nil }
        let v = ScreenView(sourceAspect: sw / sh, canvasAspect: W / H, fit: dest.screenFit, zoom: dest.screenZoom,
                           panX: dest.screenPanX, panY: dest.screenPanY)
        let r = v.contentRect
        let rw = r.w * W, rh = r.h * H
        // Core Image's origin is bottom-left; the layout is top-left, so flip y.
        screen = screen.transformed(by: CGAffineTransform(scaleX: rw / sw, y: rh / sh))
            .transformed(by: CGAffineTransform(translationX: r.l * W, y: H - r.t * H - rh))
        let canvasRect = CGRect(x: 0, y: 0, width: W, height: H)
        var out = screen.composited(over: CIImage(color: .black).cropped(to: canvasRect))

        if let ov = overlay, ov.extent.width > 0, ov.extent.height > 0 {
            let ow = dest.overlayW * W
            let oh = ow * ov.extent.height / ov.extent.width
            let placed = ov.transformed(by: CGAffineTransform(translationX: -ov.extent.minX, y: -ov.extent.minY))
                .transformed(by: CGAffineTransform(scaleX: ow / ov.extent.width, y: oh / ov.extent.height))
                .transformed(by: CGAffineTransform(translationX: dest.overlayX * W - ow / 2, y: H - (dest.overlayY * H + oh / 2)))
            out = placed.composited(over: out)
        }
        out = hidden ? CIImage(color: .black).cropped(to: canvasRect) : out.cropped(to: canvasRect)

        var pb: CVPixelBuffer?
        guard let pool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let pb else { return nil }
        ctx.render(out, to: pb)
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &format)
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pb, formatDescription: format,
                                                 sampleTiming: &timing, sampleBufferOut: &sample)
        return sample
    }

    private static func makePool(_ s: CGSize) -> CVPixelBufferPool? {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: Int(s.width),
            kCVPixelBufferHeightKey as String: Int(s.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ]
        var p: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &p)
        return p
    }
}
