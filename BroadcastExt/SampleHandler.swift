import HaishinKit
import ReplayKit
import RTMPHaishinKit
import VideoToolbox

/// Runs in the ReplayKit broadcast upload extension: a separate process with a ~50 MB memory ceiling.
/// Structure mirrors HaishinKit's official Examples/iOS/Screencast handler.
final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private var session: StreamSession?
    private var mixer = MediaMixer(captureSessionMode: .manual, multiTrackAudioMixingEnabled: true)
    private var needVideoConfiguration = true
    private var targetBitrate = 4_500_000
    private var keyframeSeconds = 2
    private var useHevc = false
    private var audioSource = 2   // 0 mic, 1 game, 2 both

    /// Reads the active channel straight from the shared group so the extension needs no app-only code.
    private static func activeDestination() -> Destination? {
        guard let d = UserDefaults(suiteName: "group.dev.livepipe") else { return nil }
        guard let data = d.data(forKey: "destinations"),
              let list = try? JSONDecoder().decode([Destination].self, from: data) else { return nil }
        let activeId = d.string(forKey: "activeId")
        return list.first { $0.id == activeId } ?? list.first
    }

    override init() {
        super.init()
        Task { await StreamSessionBuilderFactory.shared.register(RTMPSessionFactory()) }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        guard let dest = Self.activeDestination(), let url = URL(string: dest.endpoint) else {
            finishBroadcastWithError(NSError(domain: "LivePipe", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: "Add a channel in the app first."]))
            return
        }
        self.targetBitrate = dest.videoBitrate
        self.keyframeSeconds = dest.keyframeSeconds
        self.useHevc = dest.hevc
        self.audioSource = Store.prefs.audioSource
        Task {
            do {
                session = try await StreamSessionBuilderFactory.shared.make(url).build()
                // ReplayKit is memory-sensitive: cap the video queue (HaishinKit's own sample uses 5).
                var video = await mixer.videoMixerSettings
                video.mode = .passthrough
                await session?.stream.setVideoInputBufferCounts(5)
                await mixer.setVideoMixerSettings(video)
                await mixer.startRunning()
                if let session {
                    await mixer.addOutput(session.stream)
                    try await session.connect {}
                }
            } catch {
                finishBroadcastWithError(error)
            }
        }
    }

    override func broadcastFinished() {
        Task {
            await mixer.stopRunning()
            try? await session?.close()
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            Task {
                if needVideoConfiguration, let dims = sampleBuffer.formatDescription?.dimensions {
                    var settings = await session?.stream.videoSettings
                    settings?.videoSize = .init(width: CGFloat(dims.width), height: CGFloat(dims.height))
                    settings?.profileLevel = kVTProfileLevel_H264_Baseline_AutoLevel as String
                    settings?.bitRate = targetBitrate
                    settings?.maxKeyFrameIntervalDuration = Int32(keyframeSeconds)
                    // HEVC: HaishinKit 2.2 selects codec on VideoCodecSettings; wire `useHevc` to its
                    // codec field on the first Xcode build (property name varies by minor version).
                    if let settings { try? await session?.stream.setVideoSettings(settings) }
                    needVideoConfiguration = false
                }
            }
            Task { await mixer.append(sampleBuffer) }
        case .audioMic:
            if audioSource != 1, sampleBuffer.dataReadiness == .ready {   // skip mic when "game only"
                Task { await mixer.append(sampleBuffer, track: 0) }
            }
        case .audioApp:
            if audioSource != 0, sampleBuffer.dataReadiness == .ready {   // skip app when "mic only"
                Task { await mixer.append(sampleBuffer, track: 1) }
            }
        @unknown default:
            break
        }
    }
}
