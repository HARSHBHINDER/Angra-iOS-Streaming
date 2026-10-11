import AppIntents
import SwiftUI
import WidgetKit

/// Home Screen (small / medium / large) and Lock Screen (circular / rectangular / inline) widgets.
/// Patterns from what streaming and control apps ship: a status-first glance (Twitch, Twick), platform-tinted
/// letter avatars for channels (Twick), clear on/off state for toggles (Elgato Control Center) and a size
/// ladder where the small shows status + one action and the large adds a list (Spotify, YouTube Music).
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
private let emberGrad = LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.23), Color(red: 1, green: 0.54, blue: 0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
private let onGrad = LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.27), Color(red: 1, green: 0.18, blue: 0.33)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
private let goldGrad = LinearGradient(colors: [Color(red: 1, green: 0.79, blue: 0.16), Color(red: 0.91, green: 0.12, blue: 0.39)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

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

    @ViewBuilder private var background: some View {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge:
            ZStack {
                LinearGradient(colors: scheme == .dark ? [Color(white: 0.12), Color(white: 0.05)]
                                                       : [Color.white, Color(red: 0.965, green: 0.94, blue: 0.925)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(red: 1, green: 0.18, blue: 0.23).opacity(scheme == .dark ? 0.35 : 0.18), Color.clear],
                               center: .topTrailing, startRadius: 0, endRadius: 260)
                RadialGradient(colors: [Color(red: 1, green: 0.54, blue: 0).opacity(scheme == .dark ? 0.15 : 0.10), Color.clear],
                               center: .bottomLeading, startRadius: 0, endRadius: 200)
            }
        default:
            Color.clear
        }
    }

    // MARK: Home Screen

    /// Small: status + channel + one action (Go Live opens the app; while live, End works right here).
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { mark; Spacer(); statusPill }
            Spacer(minLength: 6)
            channelLine(avatarSize: 28, nameSize: 14)
            if let s = e.liveSince {
                Text(timerInterval: s...Date.distantFuture, countsDown: false)
                    .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit().padding(.top, 4)
            }
            Spacer(minLength: 6)
            if live {
                Button(intent: EndStreamIntent()) { pill("stop.fill", "End", height: 34, fill: AnyShapeStyle(Color.red)) }.buttonStyle(.plain)
            } else {
                pill("play.fill", e.active == nil ? "Set up" : "Go Live", height: 34, fill: AnyShapeStyle(emberGrad))
            }
        }
        .widgetURL(live ? openApp : goLive)
    }

    /// Medium: the glance on the left, the four controls on the right.
    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { mark; statusPill }
                Spacer(minLength: 0)
                channelLine(avatarSize: 34, nameSize: 15)
                if let s = e.liveSince {
                    Text(timerInterval: s...Date.distantFuture, countsDown: false)
                        .font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { goTile; liveControl(ToggleBreakIntent(), e.onBreak ? "play.fill" : "pause.fill", e.onBreak ? "Resume" : "Break", on: e.onBreak, wide: false) }
                GridRow {
                    liveControl(ToggleMicIntent(), e.micMuted ? "mic.slash.fill" : "mic.fill", e.micMuted ? "Unmute" : "Mute", on: e.micMuted, wide: false)
                    Link(destination: superChat) { tile("dollarsign", "Super Chat", fill: AnyShapeStyle(goldGrad)) }
                }
            }
        }
        .widgetURL(openApp)
    }

    /// Large: header, channel switcher, toggles, primary action.
    private var large: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                mark
                Text("Angra Streaming").font(.system(size: 15, weight: .bold)).lineLimit(1)
                Spacer()
                statusPill
                if let s = e.liveSince {
                    Text(timerInterval: s...Date.distantFuture, countsDown: false)
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit().frame(maxWidth: 60, alignment: .trailing)
                }
            }
            Text("CHANNELS").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.secondary).padding(.top, 2)
            if e.channels.isEmpty {
                Text("Add your first channel in the app to go live from here.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(Array(e.channels.prefix(3)), id: \.id) { d in channelRow(d) }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button(intent: ToggleRecordIntent()) { tile("record.circle", "Record", on: e.record, wide: true) }.buttonStyle(.plain)
                liveControl(ToggleBreakIntent(), e.onBreak ? "play.fill" : "pause.fill", e.onBreak ? "Resume" : "Break", on: e.onBreak, wide: true)
                liveControl(ToggleMicIntent(), e.micMuted ? "mic.slash.fill" : "mic.fill", e.micMuted ? "Unmute" : "Mute", on: e.micMuted, wide: true)
                Link(destination: superChat) { tile("dollarsign", "Super Chat", fill: AnyShapeStyle(goldGrad), wide: true) }
            }
            if live {
                Button(intent: EndStreamIntent()) { pill("stop.fill", "End stream", height: 42, fill: AnyShapeStyle(Color.red)) }.buttonStyle(.plain)
            } else {
                Link(destination: goLive) { pill("play.fill", e.active == nil ? "Set up" : "Go Live", height: 42, fill: AnyShapeStyle(emberGrad)) }
            }
        }
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

    private var mark: some View {
        Image(systemName: "dot.radiowaves.left.and.right")
            .font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white)
            .frame(width: 22, height: 22)
            .background(emberGrad, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var statusPill: some View {
        Text(live ? "● LIVE" : e.active == nil ? "SET UP" : "READY")
            .font(.system(size: 10, weight: .bold)).tracking(0.8).lineLimit(1)
            .foregroundStyle(live ? Color.white : Color.primary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(live ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.primary.opacity(0.1)), in: Capsule())
    }

    private func avatar(_ d: Destination, _ size: CGFloat) -> some View {
        let p = platform(d.url)
        return Text(String(d.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(p.name == "Kick" ? Color.black : Color.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: p.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
    }

    @ViewBuilder private func channelLine(avatarSize: CGFloat, nameSize: CGFloat) -> some View {
        if let a = e.active {
            HStack(spacing: 8) {
                avatar(a, avatarSize)
                VStack(alignment: .leading, spacing: 1) {
                    Text(a.name).font(.system(size: nameSize, weight: .semibold)).lineLimit(1)
                    Text(live ? platform(a.url).name : "\(platform(a.url).name) · \(a.height)p\(a.fps)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text("No channel yet").font(.system(size: nameSize, weight: .semibold))
                Text("Add one in the app").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func channelRow(_ d: Destination) -> some View {
        let on = d.id == e.active?.id
        return Button(intent: SelectChannelIntent(id: d.id)) {
            HStack(spacing: 10) {
                avatar(d, 26)
                Text((d.pinned ? "★ " : "") + d.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Text(platform(d.url).name).font(.caption2).foregroundStyle(.secondary)
                if on { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(ember) }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(on ? ember.opacity(0.15) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? ember : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(live)                     // the channel can't change mid-broadcast
    }

    private func pill(_ symbol: String, _ title: String, height: CGFloat, fill: AnyShapeStyle) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.white).lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: Capsule())
    }

    /// A control square: glass when off, ember-to-pink when on, a solid fill for actions.
    private func tile(_ symbol: String, _ label: String, on: Bool = false, fill: AnyShapeStyle? = nil, wide: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
            Text(label).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(on || fill != nil ? Color.white : Color.primary)
        .frame(width: wide ? nil : 60, height: 54)
        .frame(maxWidth: wide ? .infinity : nil)
        .background(fill ?? (on ? AnyShapeStyle(onGrad) : AnyShapeStyle(Color.primary.opacity(0.08))),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var goTile: some View {
        if live {
            Button(intent: EndStreamIntent()) { tile("stop.fill", "End", fill: AnyShapeStyle(Color.red)) }.buttonStyle(.plain)
        } else {
            Link(destination: goLive) { tile("play.fill", e.active == nil ? "Set up" : "Go Live", fill: AnyShapeStyle(emberGrad)) }
        }
    }

    /// Break and mute only act on a running broadcast; dimmed otherwise.
    private func liveControl(_ intent: some AppIntent, _ symbol: String, _ label: String, on: Bool, wide: Bool) -> some View {
        Button(intent: intent) { tile(symbol, label, on: on, wide: wide) }
            .buttonStyle(.plain)
            .disabled(!live)
            .opacity(live || on ? 1 : 0.45)
    }
}
