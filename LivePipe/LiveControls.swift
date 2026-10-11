import ActivityKit
import AppIntents
import Foundation
import WidgetKit

/// iOS has no floating bubble over other apps, so the stream controls live in a Live Activity (Dynamic
/// Island + Lock Screen). Buttons run these intents in the app process; they flip flags in the app group and
/// the broadcast extension applies them within a second. Shared by the app and the LiveActivity widget.
struct StreamActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var micMuted = false
        var onBreak = false
        var gameMuted = false
        var overlayHidden = false
        var dataSaver = false
        var zoomed = false
        var slots = ["mic", "break", "end"]       // which buttons to show, ActivityAction ids

        static var current: ContentState {
            ContentState(micMuted: Store.micMuted, onBreak: Store.onBreak, gameMuted: Store.gameMuted,
                         overlayHidden: Store.overlayHidden, dataSaver: Store.dataSaver, zoomed: Store.zoomed,
                         slots: ActivityAction.slots(Store.prefs.activitySlots).map(\.rawValue))
        }
    }
    var channel: String
    var start: Date
}

enum LiveControls {
    /// Called when screen capture starts; no-op if the user turned Live Activities off.
    static func start(channel: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, Activity<StreamActivity>.activities.isEmpty else { return }
        Store.gameMuted = false; Store.overlayHidden = false; Store.dataSaver = false; Store.zoomed = false
        _ = try? Activity.request(attributes: StreamActivity(channel: channel, start: Date()),
                                  content: ActivityContent(state: .current, staleDate: nil))
    }

    static func refresh() async {
        let state = StreamActivity.ContentState.current
        for a in Activity<StreamActivity>.activities { await a.update(ActivityContent(state: state, staleDate: nil)) }
        WidgetCenter.shared.reloadAllTimelines()                    // Home Screen widgets show the same state
    }

    static func end() async {
        for a in Activity<StreamActivity>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}

/// Every control the Live Activity can carry; the user picks three in Settings.
enum ActivityAction: String, CaseIterable, Identifiable {
    case mic, breakScreen = "break", end, game, overlay, saver, zoom, mark
    static let count = 3
    var id: String { rawValue }

    var label: String {
        switch self {
        case .mic: "Mute"
        case .breakScreen: "Break"
        case .end: "End"
        case .game: "Game audio"
        case .overlay: "Overlay"
        case .saver: "Data saver"
        case .zoom: "Zoom"
        case .mark: "Highlight"
        }
    }
    var onLabel: String {
        switch self {
        case .mic: "Unmute"
        case .breakScreen: "Resume"
        case .game: "Game off"
        case .overlay: "Overlay off"
        case .saver: "Saver on"
        case .zoom: "Zoomed"
        default: label
        }
    }
    var symbol: String {
        switch self {
        case .mic: "mic.fill"
        case .breakScreen: "pause.fill"
        case .end: "stop.fill"
        case .game: "speaker.slash.fill"
        case .overlay: "square.3.layers.3d"
        case .saver: "arrow.down.circle"
        case .zoom: "plus.magnifyingglass"
        case .mark: "flag.fill"
        }
    }
    func isOn(_ s: StreamActivity.ContentState) -> Bool {
        switch self {
        case .mic: s.micMuted
        case .breakScreen: s.onBreak
        case .game: s.gameMuted
        case .overlay: s.overlayHidden
        case .saver: s.dataSaver
        case .zoom: s.zoomed
        case .end: true
        case .mark: false
        }
    }

    /// Saved ids into exactly [count] distinct actions; unknown or missing ids fall back to the defaults.
    static func slots(_ ids: [String]) -> [ActivityAction] {
        var picked: [ActivityAction] = []
        for id in ids { if let a = ActivityAction(rawValue: id), !picked.contains(a), picked.count < count { picked.append(a) } }
        for a in [ActivityAction.mic, .breakScreen, .end] where picked.count < count && !picked.contains(a) { picked.append(a) }
        return picked
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

struct ToggleGameIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mute or unmute game audio"
    func perform() async throws -> some IntentResult {
        Store.gameMuted.toggle()
        await LiveControls.refresh()
        return .result()
    }
}

struct ToggleOverlayIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Show or hide overlay"
    func perform() async throws -> some IntentResult {
        Store.overlayHidden.toggle()
        await LiveControls.refresh()
        return .result()
    }
}

struct ToggleDataSaverIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Data saver"
    func perform() async throws -> some IntentResult {
        Store.dataSaver.toggle()
        await LiveControls.refresh()
        return .result()
    }
}

struct ToggleZoomIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Zoom in or out"
    func perform() async throws -> some IntentResult {
        Store.zoomed.toggle()
        await LiveControls.refresh()
        return .result()
    }
}

/// Notes the stream time in highlights.txt in the app group, to find the moment later.
struct MarkHighlightIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark highlight"
    func perform() async throws -> some IntentResult {
        guard let a = Activity<StreamActivity>.activities.first,
              let url = Store.overlayURL("highlights.txt") else { return .result() }
        let s = Int(Date().timeIntervalSince(a.attributes.start))
        let line = String(format: "%@  stream time %d:%02d:%02d  %@\n",
                          Date().formatted(date: .numeric, time: .shortened), s / 3600, s % 3600 / 60, s % 60, a.attributes.channel)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
        return .result()
    }
}

/// Home Screen widget: make a channel the active one, right from the widget.
struct SelectChannelIntent: AppIntent {
    static let title: LocalizedStringResource = "Choose channel"
    @Parameter(title: "Channel") var id: String
    init() {}
    init(id: String) { self.id = id }
    func perform() async throws -> some IntentResult {
        Store.activeId = id
        return .result()
    }
}

/// Home Screen widget: record the next broadcast on/off.
struct ToggleRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Record while streaming"
    func perform() async throws -> some IntentResult {
        var p = Store.prefs
        p.recordWhileStreaming.toggle()
        Store.prefs = p
        return .result()
    }
}
