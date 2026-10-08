import Foundation

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

    var endpoint: String { key.isEmpty ? url : url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + key }
}

struct Prefs: Codable, Equatable {
    var recordWhileStreaming = false
    var audioSource = 2          // 0 mic, 1 app/game, 2 both
    var adaptiveBitrate = true
    // Recording reuses the active channel's resolution/bitrate (single encoder). No floating bubble on
    // iOS: the OS has no cross-app overlay — status shows via the OS indicator (Live Activity planned).
    static let audioMic = 0, audioGame = 1, audioMix = 2
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
}
