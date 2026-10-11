import AppIntents
import SwiftUI
import WidgetKit

/// Home Screen (small / medium / large) and Lock Screen (circular / rectangular / inline) widgets, in the same
/// language as the Android ones: a glance (platform avatar, status capsule, a big state line that becomes the live
/// timer, one-line caption) and Shortcuts-style action tiles (icon top-left, label bottom-left; filled = on).
/// Go Live opens the app (iOS only lets the app start a broadcast); End, Break, Mute, Record and channel
/// switching work right on the widget.
struct StreamWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreamWidget", provider: StreamProvider()) { e in StreamWidgetView(e: e) }
            .configurationDisplayName("Angra Streaming")
            .description("Go live, see your live time, and control break, mute and channels from the Home and Lock Screen.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StreamEntry: TimelineEntry {
    let date: Date
    let channels: [Destination]
    let active: Destination?
    let liveSince: Date?
    let micMuted: Bool
    let onBreak: Bool
    let record: Bool

    static func now() -> StreamEntry {
        let all = Store.destinations
        let since = Store.liveSince
        return StreamEntry(date: Date(), channels: all.filter(\.pinned) + all.filter { !$0.pinned }, active: Store.active,
                           liveSince: since > 0 ? Date(timeIntervalSince1970: since) : nil,
                           micMuted: Store.micMuted, onBreak: Store.onBreak, record: Store.prefs.recordWhileStreaming)
    }

    /// Gallery preview: shows the widget with content, not an empty state.
    static let sample: StreamEntry = {
        let a = Destination(name: "Ranked grind", url: "rtmps://a.rtmp.youtube.com/live2")
        let b = Destination(name: "Chill builds", url: "rtmp://live.twitch.tv/app")
        let c = Destination(name: "Late night IRL", url: "rtmps://live-api-s.facebook.com:443/rtmp/")
        return StreamEntry(date: Date(), channels: [a, b, c], active: a, liveSince: nil, micMuted: false, onBreak: false, record: false)
    }()
}

struct StreamProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreamEntry { .sample }
    func getSnapshot(in context: Context, completion: @escaping (StreamEntry) -> Void) {
        completion(context.isPreview && Store.destinations.isEmpty ? .sample : .now())
    }
    // State changes push reloads (app, broadcast extension, intents), so one entry is enough.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreamEntry>) -> Void) {
        completion(Timeline(entries: [.now()], policy: .never))
    }
}

private let ember = Color(red: 0.95, green: 0.33, blue: 0.18)
private func grad(_ a: Color, _ b: Color) -> AnyShapeStyle {
    AnyShapeStyle(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing))
}
private let goFill = grad(Color(red: 1, green: 0.18, blue: 0.23), Color(red: 1, green: 0.54, blue: 0))
private let endFill = grad(Color(red: 1, green: 0.27, blue: 0.23), Color(red: 0.84, green: 0, blue: 0.08))
private let onFill = grad(Color(red: 1, green: 0.42, blue: 0.27), Color(red: 1, green: 0.18, blue: 0.33))
private let scFill = grad(Color(red: 1, green: 0.76, blue: 0.2), Color(red: 0.94, green: 0.21, blue: 0.42))

private func platform(_ url: String) -> (name: String, colors: [Color]) {
    if url.contains("youtube") { return ("YouTube", [Color(red: 1, green: 0, blue: 0.2), Color(red: 0.8, green: 0, blue: 0)]) }
    if url.contains("twitch") || url.contains("live-video.net") { return ("Twitch", [Color(red: 0.66, green: 0.44, blue: 1), Color(red: 0.57, green: 0.27, blue: 1)]) }
    if url.contains("kick") { return ("Kick", [Color(red: 0.42, green: 1, blue: 0.23), Color(red: 0.33, green: 0.99, blue: 0.09)]) }
    if url.contains("facebook") { return ("Facebook", [Color(red: 0.23, green: 0.55, blue: 1), Color(red: 0.09, green: 0.47, blue: 0.95)]) }
    return ("RTMP", [Color(red: 1, green: 0.18, blue: 0.23), Color(red: 1, green: 0.54, blue: 0)])
}

struct StreamWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let e: StreamEntry
    private var live: Bool { e.liveSince != nil }
    private let goLive = URL(string: "angra://golive")!
    private let openApp = URL(string: "angra://open")!
    private let superChat = URL(string: "angra://superchat")!

    var body: some View {
        content.containerBackground(for: .widget) { background }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: inline
        }
    }

    /// Apple's widget surface (systemBackground over secondary) with one soft ember light in the corner.
    @ViewBuilder private var background: some View {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge:
            ZStack {
                LinearGradient(colors: scheme == .dark ? [Color(red: 0.11, green: 0.11, blue: 0.12), Color(red: 0.06, green: 0.06, blue: 0.07)]
                                                       : [Color.white, Color(red: 0.95, green: 0.95, blue: 0.97)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(red: 1, green: 0.18, blue: 0.23).opacity(scheme == .dark ? 0.28 : 0.14), Color.clear],
                               center: .topTrailing, startRadius: 0, endRadius: 240)
            }
        default:
            Color.clear
        }
    }

    // MARK: Home Screen

    /// Small: the glance. One tap target (iOS small widgets): Go Live, or open the app while live.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) { activeAvatar(40); Spacer(minLength: 4); statusPill }
            Spacer(minLength: 0)
            stateLine(26)
            caption.padding(.top, 2)
        }
        .widgetURL(live ? openApp : goLive)
    }

    /// Medium: the glance on the left, a 2x2 grid of actions on the right.
    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) { activeAvatar(36); Spacer(minLength: 4); statusPill }
                Spacer(minLength: 0)
                stateLine(22)
                caption.padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { goTile; breakTile }
                GridRow { muteTile; superChatTile }
            }
            .frame(maxWidth: .infinity)
        }
        .widgetURL(openApp)
    }

    /// Large: glance + primary action, the channel list (iOS list rhythm), four actions.
    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                activeAvatar(44)
                VStack(alignment: .leading, spacing: 2) { stateLine(22); caption.lineLimit(1) }
                Spacer(minLength: 8)
                primaryCapsule
            }
            Text("CHANNELS").font(.system(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
                .padding(.top, 16).padding(.bottom, 2)
            if e.channels.isEmpty {
                Text("Add your first channel in the app to go live from here.").font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
            }
            ForEach(Array(e.channels.prefix(3).enumerated()), id: \.element.id) { i, d in
                if i > 0 { Divider().padding(.leading, 42) }
                channelRow(d)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Button(intent: ToggleRecordIntent()) {
                    tile("record.circle", e.record ? "Recording" : "Record", fill: e.record ? endFill : nil)
                }.buttonStyle(.plain)
                breakTile
                muteTile
                superChatTile
            }
            .frame(height: 68)
        }
        .widgetURL(openApp)
    }

    // MARK: Lock Screen

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let s = e.liveSince {
                VStack(spacing: 0) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 11, weight: .bold))
                    Text(timerInterval: s...Date.distantFuture, countsDown: false)
                        .font(.system(size: 11, weight: .semibold)).monospacedDigit().multilineTextAlignment(.center)
                }
            } else {
                Image(systemName: "play.fill").font(.system(size: 20, weight: .bold))
            }
        }
        .widgetURL(live ? openApp : goLive)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(live ? "LIVE" : "Ready to go live", systemImage: live ? "dot.radiowaves.left.and.right" : "play.circle.fill")
                .font(.headline).lineLimit(1)
            if let s = e.liveSince {
                Text(timerInterval: s...Date.distantFuture, countsDown: false)
                    .font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
            }
            Text(e.active?.name ?? "Add a channel").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(live ? openApp : goLive)
    }

    @ViewBuilder private var inline: some View {
        if let s = e.liveSince {
            Text("LIVE ") + Text(timerInterval: s...Date.distantFuture, countsDown: false)
        } else {
            Text("Ready · \(e.active?.name ?? "Angra Streaming")")
        }
    }

    // MARK: Pieces

    private var statusPill: some View {
        Text(live ? "● LIVE" : e.active == nil ? "SET UP" : "READY")
            .font(.system(size: 10, weight: .bold)).tracking(0.6).lineLimit(1)
            .foregroundStyle(live ? Color.white : Color.primary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(live ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.primary.opacity(0.1)), in: Capsule())
    }

    /// Big state line, the Live Activity hierarchy: "Ready" / "Set up", or the running timer while live.
    private func stateLine(_ size: CGFloat) -> some View {
        Group {
            if let s = e.liveSince {
                Text(timerInterval: s...Date.distantFuture, countsDown: false).monospacedDigit()
            } else {
                Text(e.active == nil ? "Set up" : "Ready")
            }
        }
        .font(.system(size: size, weight: .bold)).tracking(-0.4).lineLimit(1).minimumScaleFactor(0.6)
    }

    private var caption: some View {
        Text(e.active.map { live ? "\($0.name) · \(platform($0.url).name)" : "\($0.name) · \($0.height)p\($0.fps)" }
             ?? "Add a channel to go live")
            .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
    }

    @ViewBuilder private func activeAvatar(_ size: CGFloat) -> some View {
        if let a = e.active {
            avatar(a, size)
        } else {
            Image(systemName: "plus").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(Color.white)
                .frame(width: size, height: size).background(goFill, in: Circle())
        }
    }

    /// Letter avatar tinted with the channel's platform colour (the Twick / Twitch widget pattern).
    private func avatar(_ d: Destination, _ size: CGFloat) -> some View {
        let p = platform(d.url)
        return Text(String(d.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.43, weight: .bold))
            .foregroundStyle(p.name == "Kick" ? Color.black : Color.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: p.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
    }

    private func channelRow(_ d: Destination) -> some View {
        Button(intent: SelectChannelIntent(id: d.id)) {
            HStack(spacing: 12) {
                avatar(d, 30)
                Text((d.pinned ? "★ " : "") + d.name).font(.system(size: 15, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text(platform(d.url).name).font(.caption).foregroundStyle(.secondary)
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(ember)
                    .frame(width: 18).opacity(d.id == e.active?.id ? 1 : 0)
            }
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(live)                     // the channel can't change mid-broadcast
    }

    private var capsuleLabel: some View {
        Text(live ? "End" : e.active == nil ? "Set up" : "Go Live")
            .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white).lineLimit(1)
            .padding(.horizontal, 14).frame(height: 34)
            .background(live ? AnyShapeStyle(Color.red) : goFill, in: Capsule())
    }

    @ViewBuilder private var primaryCapsule: some View {
        if live {
            Button(intent: EndStreamIntent()) { capsuleLabel }.buttonStyle(.plain)
        } else {
            Link(destination: goLive) { capsuleLabel }
        }
    }

    /// Shortcuts-style action: icon top-left, label bottom-left. Filled when on / a primary action, glass when off.
    private func tile(_ symbol: String, _ label: String, on: Bool = false, fill: AnyShapeStyle? = nil) -> some View {
        let lit = on || fill != nil
        return VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
            Spacer(minLength: 4)
            Text(label).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .foregroundStyle(lit ? Color.white : Color.primary)
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(fill ?? (on ? onFill : AnyShapeStyle(Color.primary.opacity(0.08))),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var goTile: some View {
        if live {
            Button(intent: EndStreamIntent()) { tile("stop.fill", "End", fill: endFill) }.buttonStyle(.plain)
        } else {
            Link(destination: goLive) { tile("play.fill", e.active == nil ? "Set up" : "Go Live", fill: goFill) }
        }
    }

    private var breakTile: some View {
        liveControl(ToggleBreakIntent(), "pause.fill", e.onBreak ? "On break" : "Break", on: e.onBreak)
    }

    private var muteTile: some View {
        liveControl(ToggleMicIntent(), e.micMuted ? "mic.slash.fill" : "mic.fill", e.micMuted ? "Muted" : "Mute", on: e.micMuted)
    }

    private var superChatTile: some View {
        Link(destination: superChat) { tile("dollarsign", "Super Chat", fill: scFill) }
    }

    /// Break and mute only act on a running broadcast; dimmed otherwise.
    private func liveControl(_ intent: some AppIntent, _ symbol: String, _ label: String, on: Bool) -> some View {
        Button(intent: intent) { tile(symbol, label, on: on) }
            .buttonStyle(.plain)
            .disabled(!live)
            .opacity(live || on ? 1 : 0.45)
    }
}
