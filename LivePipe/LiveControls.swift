import ActivityKit
import AppIntents
import Foundation

/// iOS has no floating bubble over other apps, so the stream controls live in a Live Activity (Dynamic
/// Island + Lock Screen). Buttons run these intents in the app process; they flip flags in the app group and
/// the broadcast extension applies them within a second. Shared by the app and the LiveActivity widget.
struct StreamActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var micMuted = false
        var onBreak = false
    }
    var channel: String
    var start: Date
}

enum LiveControls {
    /// Called when screen capture starts; no-op if the user turned Live Activities off.
    static func start(channel: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, Activity<StreamActivity>.activities.isEmpty else { return }
        _ = try? Activity.request(attributes: StreamActivity(channel: channel, start: Date()),
                                  content: ActivityContent(state: StreamActivity.ContentState(), staleDate: nil))
    }

    static func refresh() async {
        let state = StreamActivity.ContentState(micMuted: Store.micMuted, onBreak: Store.onBreak)
        for a in Activity<StreamActivity>.activities { await a.update(ActivityContent(state: state, staleDate: nil)) }
    }

    static func end() async {
        for a in Activity<StreamActivity>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}

struct ToggleMicIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mute or unmute microphone"
    func perform() async throws -> some IntentResult {
        Store.micMuted.toggle()
        await LiveControls.refresh()
        return .result()
    }
}

struct ToggleBreakIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start or end break"
    func perform() async throws -> some IntentResult {
        Store.onBreak.toggle()
        await LiveControls.refresh()
        return .result()
    }
}

struct EndStreamIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End stream"
    func perform() async throws -> some IntentResult {
        Store.stopRequested = true
        await LiveControls.end()
        return .result()
    }
}
