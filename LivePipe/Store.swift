import CoreGraphics
import Foundation
import ImageIO

/// Shared between the app and the broadcast extension via the app group.
/// Mirrors the Android Destination/Prefs model so both platforms behave the same.
let appGroup = "group.dev.livepipe"

struct Destination: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name = ""
    var url = "rtmps://"
    var key = ""
    var width = 1280
    var height = 720
    var fps = 30
    var videoBitrate = 4_500_000
    var audioBitrate = 128_000
    var sampleRate = 48_000
    var stereo = true
    var hevc = false            // false = H.264 (universal), true = H.265/HEVC
    var keyframeSeconds = 2     // I-frame interval; 2 s is the platform default
    var portrait = false        // landscape vs portrait (iOS screen broadcast follows device orientation)
    var delaySeconds = 0        // OBS-style stream delay (stored; HaishinKit has no delay API yet)
    // Scene layout (see ScreenView): screen fill/fit + zoom + pan; overlay centre + width, canvas fractions.
    var screenFit = false       // false = fill the canvas (no borders), true = show the whole screen
    var screenZoom = 1.0        // extra zoom on top of fill/fit, 1...4
    var screenPanX = 0.0        // -1...1 across the pannable range
    var screenPanY = 0.0
    var overlayFile = ""        // PNG in the app-group container; empty = no overlay
    var overlayX = 0.82
    var overlayY = 0.18
    var overlayW = 0.25
    var pinned = false          // favourites sit at the top of the list, no limit
    var ytSource = ""           // YouTube @handle, channel ID or live link for Super Chat alerts
    var alertX = 0.5            // Super Chat card centre, canvas fractions
    var alertY = 0.2
    var alertW = 0.42           // card width as a fraction of canvas width (height follows the card)

    var endpoint: String { key.isEmpty ? url : url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + key }
    /// Stream canvas size in pixels (portrait channels swap the sides).
    var canvas: CGSize { portrait ? CGSize(width: height, height: width) : CGSize(width: width, height: height) }
}

extension Destination {
    /// Tolerant decoding: channels saved by older versions miss newer fields and must still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Destination()
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? fallback }
        id = v(.id, d.id); name = v(.name, d.name); url = v(.url, d.url); key = v(.key, d.key)
        width = v(.width, d.width); height = v(.height, d.height); fps = v(.fps, d.fps)
        videoBitrate = v(.videoBitrate, d.videoBitrate); audioBitrate = v(.audioBitrate, d.audioBitrate)
        sampleRate = v(.sampleRate, d.sampleRate); stereo = v(.stereo, d.stereo); hevc = v(.hevc, d.hevc)
        keyframeSeconds = v(.keyframeSeconds, d.keyframeSeconds); portrait = v(.portrait, d.portrait)
        delaySeconds = v(.delaySeconds, d.delaySeconds)
        screenFit = v(.screenFit, d.screenFit); screenZoom = v(.screenZoom, d.screenZoom)
        screenPanX = v(.screenPanX, d.screenPanX); screenPanY = v(.screenPanY, d.screenPanY)
        overlayFile = v(.overlayFile, d.overlayFile)
        overlayX = v(.overlayX, d.overlayX); overlayY = v(.overlayY, d.overlayY); overlayW = v(.overlayW, d.overlayW)
        pinned = v(.pinned, d.pinned)
        ytSource = v(.ytSource, d.ytSource)
        alertX = v(.alertX, d.alertX); alertY = v(.alertY, d.alertY); alertW = v(.alertW, d.alertW)
    }
}

struct Prefs: Codable, Equatable {
    var recordWhileStreaming = false
    var audioSource = 2          // 0 mic, 1 app/game, 2 both
    var adaptiveBitrate = true
    var micVolume = 1.0          // audio mixer, 0...1.5 (0 = muted)
    var gameVolume = 1.0
    var breakFile = ""           // break screen image in the app group; empty = plain black, no branding
    var activitySlots = ["mic", "break", "end"]   // Live Activity buttons, ActivityAction ids
    var superChat = false        // show YouTube Super Chats on stream
    var ytApiKey = ""            // the streamer's own YouTube Data API key
    var alertStyle = 0           // SuperChatCard.styles index
    var alertSeconds = 8
    var alertShowTotal = true    // add the supporter's running total this stream
    var theme = "original"       // Theme.all id
    // Recording reuses the active channel's resolution/bitrate (single encoder). No floating bubble on
    // iOS: the OS has no cross-app overlay — status shows via the OS indicator (Live Activity planned).
    static let audioMic = 0, audioGame = 1, audioMix = 2
}

extension Prefs {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Prefs()
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? fallback }
        recordWhileStreaming = v(.recordWhileStreaming, d.recordWhileStreaming)
        audioSource = v(.audioSource, d.audioSource); adaptiveBitrate = v(.adaptiveBitrate, d.adaptiveBitrate)
        micVolume = v(.micVolume, d.micVolume); gameVolume = v(.gameVolume, d.gameVolume)
        breakFile = v(.breakFile, d.breakFile)
        activitySlots = v(.activitySlots, d.activitySlots)
        superChat = v(.superChat, d.superChat); ytApiKey = v(.ytApiKey, d.ytApiKey)
        alertStyle = v(.alertStyle, d.alertStyle); alertSeconds = v(.alertSeconds, d.alertSeconds)
        alertShowTotal = v(.alertShowTotal, d.alertShowTotal)
        theme = v(.theme, d.theme)
    }
}

/// Screen-layer geometry, identical to Android's Scene.kt so both apps and both editors agree.
/// The screen is first fitted into the canvas (content rect cw×ch, centred), then a window 1/z wide and tall,
/// centred at (cx, cy), is stretched over the whole canvas. rx/ry = how far the centre may pan from 0.5.
struct ScreenView {
    let z, cx, cy, cw, ch, rx, ry: Double

    /// Where the screen lands on the canvas: (left, top, width, height) as canvas fractions, top-left origin.
    var contentRect: (l: Double, t: Double, w: Double, h: Double) {
        ((0.5 - cw / 2 - cx) * z + 0.5, (0.5 - ch / 2 - cy) * z + 0.5, cw * z, ch * z)
    }

    static let maxZoom = 4.0

    init(sourceAspect sa: Double, canvasAspect ca: Double, fit: Bool, zoom: Double, panX: Double, panY: Double) {
        cw = min(1, sa / ca); ch = min(1, ca / sa)
        z = (fit ? 1 : max(1 / cw, 1 / ch)) * min(max(zoom, 1), Self.maxZoom)   // fill = smallest zoom with no borders
        let v = 1 / z
        // Filling keeps the window on the content (borders never return); fitting may roam the whole frame.
        rx = max(0, ((fit ? 1 : cw) - v) / 2); ry = max(0, ((fit ? 1 : ch) - v) / 2)
        cx = 0.5 + rx * min(max(panX, -1), 1); cy = 0.5 + ry * min(max(panY, -1), 1)
    }

    /// Inverse of the pan mapping: a window centre back to pan -1...1.
    static func pan(centre: Double, range: Double) -> Double { range <= 0 ? 0 : min(max((centre - 0.5) / range, -1), 1) }
}

/// Keys are stored in the iOS Keychain in a shipping build; here they ride in the shared group for the
/// reference app. REPORT.md calls this out as test-only.
enum Store {
    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static var destinations: [Destination] {
        get { (try? JSONDecoder().decode([Destination].self, from: defaults.data(forKey: "destinations") ?? Data())) ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "destinations") }
    }
    static var activeId: String? {
        get { defaults.string(forKey: "activeId") }
        set { defaults.set(newValue, forKey: "activeId") }
    }
    static var active: Destination? { destinations.first { $0.id == activeId } ?? destinations.first }

    static var prefs: Prefs {
        get { (try? JSONDecoder().decode(Prefs.self, from: defaults.data(forKey: "prefs") ?? Data())) ?? Prefs() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "prefs") }
    }

    /// Live controls: written by the Live Activity buttons, read by the broadcast extension once a second.
    static var micMuted: Bool {
        get { defaults.bool(forKey: "micMuted") }
        set { defaults.set(newValue, forKey: "micMuted") }
    }
    /// Break screen on air (stream keeps running; viewers see black or the break image).
    static var onBreak: Bool {
        get { defaults.bool(forKey: "onBreak") }
        set { defaults.set(newValue, forKey: "onBreak") }
    }
    static var gameMuted: Bool {
        get { defaults.bool(forKey: "gameMuted") }
        set { defaults.set(newValue, forKey: "gameMuted") }
    }
    static var overlayHidden: Bool {
        get { defaults.bool(forKey: "overlayHidden") }
        set { defaults.set(newValue, forKey: "overlayHidden") }
    }
    static var dataSaver: Bool {
        get { defaults.bool(forKey: "dataSaver") }
        set { defaults.set(newValue, forKey: "dataSaver") }
    }
    static var zoomed: Bool {
        get { defaults.bool(forKey: "zoomed") }
        set { defaults.set(newValue, forKey: "zoomed") }
    }
    /// Super Chat connection status written by the extension for the app ("Connected…", errors).
    static var superChatStatus: String {
        get { defaults.string(forKey: "superChatStatus") ?? "" }
        set { defaults.set(newValue, forKey: "superChatStatus") }
    }
    /// Set by the app's "Send test alert"; the extension plays a sample card of that tier and clears it.
    static var testAlertTier: Int {
        get { defaults.integer(forKey: "testAlertTier") }
        set { defaults.set(newValue, forKey: "testAlertTier") }
    }
    /// When the broadcast started (seconds since 1970), 0 = not live. Written by the extension for the widgets.
    static var liveSince: Double {
        get { defaults.double(forKey: "liveSince") }
        set { defaults.set(newValue, forKey: "liveSince") }
    }
    static var stopRequested: Bool {
        get { defaults.bool(forKey: "stopRequested") }
        set { defaults.set(newValue, forKey: "stopRequested") }
    }

    /// Overlay images live in the app-group container so the broadcast extension can read them.
    static func overlayURL(_ file: String) -> URL? {
        guard !file.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent(file)
    }
}

/// Animated overlays (GIF): per-frame delays, read the way browsers do (tiny delays become 0.1 s).
enum AnimatedImage {
    static func delays(_ src: CGImageSource) -> [Double] {
        (0..<CGImageSourceGetCount(src)).map { i in
            let gif = (CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any])?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let d = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            return d < 0.011 ? 0.1 : d
        }
    }

    /// Frame showing at time t (seconds), looping.
    static func frame(at t: Double, delays: [Double]) -> Int {
        let total = delays.reduce(0, +)
        guard total > 0 else { return 0 }
        var r = t.truncatingRemainder(dividingBy: total)
        for (i, d) in delays.enumerated() { if r < d { return i }; r -= d }
        return delays.count - 1
    }

    /// Decodes one frame downsampled to maxPixels, so memory stays bounded whatever the file size.
    static func image(_ src: CGImageSource, _ i: Int, maxPixels: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(src, i, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary)
    }
}
