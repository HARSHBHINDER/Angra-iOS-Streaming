import PhotosUI
import ReplayKit
import SwiftUI
import WidgetKit

@main
struct LivePipeApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

// MARK: - Brand

/// One app theme: Apple's grouped structure stays, a theme swaps the background, tint, button gradient and the two
/// glow lights. dark = nil follows the system (Original). Same ids and colours as Android's Palettes.
struct Theme: Identifiable, Equatable {
    let id, name: String
    let dark: Bool?
    let bg, card, accent: UInt32
    let brush, glow: [UInt32]

    /// Tron Legacy = ggsci pal_tron("legacy"); Cyberpunk = CDPR acid yellow, red, turquoise; Nord = nordtheme.com.
    static let all: [Theme] = [
        Theme(id: "matte", name: "Matte Black", dark: true, bg: 0xFF000000, card: 0xFF111111, accent: 0xFFA1A1A6, brush: [0xFF4A4A4E, 0xFF242426], glow: [0x14FFFFFF, 0x00000000]),
        Theme(id: "white", name: "White", dark: false, bg: 0xFFFFFFFF, card: 0xFFF5F5F7, accent: 0xFF1D1D1F, brush: [0xFF3A3A3C, 0xFF1D1D1F], glow: [0x00000000, 0x00000000]),
        Theme(id: "original", name: "Original", dark: nil, bg: 0xFF000000, card: 0xFF1C1C1E, accent: 0xFFF2542D, brush: [0xFFFF2D3A, 0xFFFF8A00], glow: [0xFFFF3B30, 0xFFFF8A00]),
        Theme(id: "tron", name: "Tron Legacy", dark: true, bg: 0xFF02070B, card: 0xFF0A161D, accent: 0xFF6EE2FF, brush: [0xFFF79D1E, 0xFFFF410D], glow: [0xFF6EE2FF, 0xFFF79D1E]),
        Theme(id: "cyberpunk", name: "Cyberpunk", dark: true, bg: 0xFF0B0A0F, card: 0xFF16141C, accent: 0xFFFCEE0A, brush: [0xFFFF003C, 0xFFB8002B], glow: [0xFFFCEE0A, 0xFF00F0FF]),
        Theme(id: "whiteninja", name: "White Ninja", dark: false, bg: 0xFFF6F3EC, card: 0xFFFFFFFF, accent: 0xFFB3001B, brush: [0xFFD7263D, 0xFF8B0011], glow: [0xFFD7263D, 0x00000000]),
        Theme(id: "blackninja", name: "Black Ninja", dark: true, bg: 0xFF050505, card: 0xFF121212, accent: 0xFFE01E37, brush: [0xFFE01E37, 0xFF6A040F], glow: [0xFF9D0208, 0x00000000]),
        Theme(id: "synthwave", name: "Synthwave", dark: true, bg: 0xFF150A26, card: 0xFF22123B, accent: 0xFFFF4F9A, brush: [0xFFFF4F9A, 0xFFFF9E3D], glow: [0xFFFF4F9A, 0xFF7B2FF7]),
        Theme(id: "aurora", name: "Aurora", dark: true, bg: 0xFF040A16, card: 0xFF0C1729, accent: 0xFF3DDC97, brush: [0xFF3DDC97, 0xFF2B8FED], glow: [0xFF3DDC97, 0xFF7F5AF0]),
        Theme(id: "glass", name: "Liquid Glass", dark: false, bg: 0xFFEAF1F8, card: 0xFFF9FBFE, accent: 0xFF007AFF, brush: [0xFF5AC8FA, 0xFF007AFF], glow: [0xFF5AC8FA, 0xFFBF5AF2]),
        Theme(id: "ocean", name: "Deep Ocean", dark: true, bg: 0xFF03111C, card: 0xFF0A2031, accent: 0xFF22C3E6, brush: [0xFF48CAE4, 0xFF0077B6], glow: [0xFF0096C7, 0xFF00B4D8]),
        Theme(id: "sakura", name: "Sakura", dark: false, bg: 0xFFFFF4F6, card: 0xFFFFFFFF, accent: 0xFFE0457B, brush: [0xFFFF8FAB, 0xFFE0457B], glow: [0xFFFF8FAB, 0xFFFFC2D1]),
        Theme(id: "matrix", name: "Matrix", dark: true, bg: 0xFF000400, card: 0xFF051208, accent: 0xFF00E676, brush: [0xFF1DB954, 0xFF0A6E2A], glow: [0xFF00FF41, 0x00000000]),
        Theme(id: "vaporwave", name: "Vaporwave", dark: true, bg: 0xFF1C1033, card: 0xFF281845, accent: 0xFF01CDFE, brush: [0xFFFF71CE, 0xFFB967FF], glow: [0xFFFF71CE, 0xFF01CDFE]),
        Theme(id: "gold", name: "Gold Luxe", dark: true, bg: 0xFF0B0906, card: 0xFF17140D, accent: 0xFFD4AF37, brush: [0xFFE6C55A, 0xFFA87B12], glow: [0xFFD4AF37, 0x00000000]),
        Theme(id: "nord", name: "Nord", dark: true, bg: 0xFF2E3440, card: 0xFF3B4252, accent: 0xFF88C0D0, brush: [0xFF81A1C1, 0xFF5E81AC], glow: [0xFF88C0D0, 0xFFB48EAD]),
        Theme(id: "dune", name: "Dune", dark: false, bg: 0xFFF2E8DA, card: 0xFFFFF9F0, accent: 0xFFC2410C, brush: [0xFFF59E0B, 0xFFC2410C], glow: [0xFFF59E0B, 0xFFC2410C]),
        Theme(id: "ultraviolet", name: "Ultraviolet", dark: true, bg: 0xFF0B0515, card: 0xFF170B2A, accent: 0xFFB57BFF, brush: [0xFFA855F7, 0xFF6D28D9], glow: [0xFFA855F7, 0xFF3B82F6]),
        Theme(id: "titanium", name: "Titanium", dark: false, bg: 0xFFE4E4E1, card: 0xFFF4F4F2, accent: 0xFF55555A, brush: [0xFF8E8E93, 0xFF48484A], glow: [0x00000000, 0x00000000]),
        Theme(id: "hologram", name: "Hologram", dark: false, bg: 0xFFF3F0FF, card: 0xFFFFFFFF, accent: 0xFF7C5CFF, brush: [0xFFFF7AD9, 0xFF7C5CFF, 0xFF3DE1FF], glow: [0xFFFF7AD9, 0xFF3DE1FF]),
    ]
    static func byId(_ id: String) -> Theme { all.first { $0.id == id } ?? all[2] }
    /// Cached so view bodies don't decode prefs on every access; set by the Settings picker.
    static var current = byId(Store.prefs.theme)
    var scheme: ColorScheme? { dark.map { $0 ? .dark : .light } }
}

extension Color {
    init(argb: UInt32) {
        self.init(.sRGB, red: Double(argb >> 16 & 0xFF) / 255, green: Double(argb >> 8 & 0xFF) / 255,
                  blue: Double(argb & 0xFF) / 255, opacity: Double(argb >> 24) / 255)
    }
    /// The theme tint (Original: Angra ember, the oni icon's flame).
    static var ember: Color { Color(argb: Theme.current.accent) }
}
var emberGradient: LinearGradient {
    LinearGradient(colors: Theme.current.brush.map(Color.init(argb:)), startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Grouped background with the theme's two glows behind the large title — the app's signature.
struct EmberBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark, t = Theme.current
        let g = t.glow.map(Color.init(argb:))
        ZStack {
            if t.dark == nil { Color(.systemGroupedBackground) } else { Color(argb: t.bg) }
            RadialGradient(colors: [g[0].opacity(dark ? 0.42 : 0.20), .clear], center: .topTrailing, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [g[1].opacity(dark ? 0.22 : 0.12), .clear],
                           center: UnitPoint(x: 0, y: 0.12), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

/// Theme grid in the iOS app-icon picker style: a mini app per theme, the chosen one ringed in its own tint.
struct ThemePicker: View {
    @Binding var selected: String
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
            ForEach(Theme.all) { t in
                let on = t.id == selected
                let card = Color(argb: t.dark == nil ? 0xFF1C1C1E : t.card)
                Button { selected = t.id } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Color(argb: t.bg)
                            RadialGradient(colors: [Color(argb: t.glow[0]).opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 90)
                            VStack(alignment: .leading, spacing: 5) {
                                Capsule().fill(t.dark == false ? Color.black : Color.white).frame(width: 30, height: 6)
                                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(card).frame(height: 18)
                                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(card).frame(height: 10)
                                Spacer(minLength: 0)
                                Capsule().fill(LinearGradient(colors: t.brush.map(Color.init(argb:)), startPoint: .leading, endPoint: .trailing))
                                    .frame(height: 14)
                            }
                            .padding(8)
                        }
                        .aspectRatio(0.72, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: on ? 12 : 16, style: .continuous))
                        .padding(on ? 4 : 0)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(on ? Color(argb: t.accent) : Color(.separator), lineWidth: on ? 2.5 : 0.5))
                        Text(t.name).font(.caption.weight(on ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
                            .foregroundStyle(on ? Color(argb: t.accent) : .primary)
                    }
                }
                .buttonStyle(PressScale())
            }
        }
        .padding(.vertical, 6)
    }
}

func platformOf(_ url: String) -> String {
    if url.contains("youtube") { return "YouTube" }
    if url.contains("twitch") { return "Twitch" }
    if url.contains("facebook") { return "Facebook" }
    if url.contains("kick") { return "Kick" }
    return "RTMP"
}

/// Apple press feedback: a quick, critically damped scale-down on touch.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
    }
}

// MARK: - Shell

struct RootView: View {
    @State private var tab = 0
    @State private var themeId = Theme.current.id
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TabView(selection: $tab) {
            StreamTab(tab: $tab).tag(0).tabItem { Label("Stream", systemImage: "dot.radiowaves.left.and.right") }
            ChannelsTab().tag(1).tabItem { Label("Channels", systemImage: "list.bullet") }
            SettingsTab().tag(2).tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.ember)
        .id(themeId)                                     // a new theme rebuilds every screen with its colours
        .preferredColorScheme(Theme.current.scheme)
        .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in themeId = Theme.current.id }
        // Home Screen widget links. Go Live opens the system broadcast picker (only the app may start a broadcast).
        .onOpenURL { url in
            switch url.host {
            case "golive":
                tab = Store.active == nil ? 1 : 0
                if Store.active != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { BroadcastLauncher.shared.open() }
                }
            case "superchat":
                tab = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NotificationCenter.default.post(name: .openSuperChat, object: nil) }
            default:
                tab = 0
            }
        }
        // Widgets show channels and settings; refresh them whenever the user leaves the app.
        .onChange(of: phase) { _, p in if p == .background { WidgetCenter.shared.reloadAllTimelines() } }
    }
}

extension Notification.Name {
    static let openSuperChat = Notification.Name("angra.openSuperChat")
    static let themeChanged = Notification.Name("angra.themeChanged")
}

// MARK: - Stream

/// iOS only lets the system picker start a ReplayKit broadcast. We keep one picker alive (invisible)
/// and press its button from our own Go Live control, so the design stays ours.
@MainActor final class BroadcastLauncher {
    static let shared = BroadcastLauncher()
    let picker: RPSystemBroadcastPickerView = {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        v.preferredExtension = "dev.livepipe.app.broadcast"
        v.showsMicrophoneButton = true
        return v
    }()
    func open() {
        for case let b as UIButton in picker.subviews { b.sendActions(for: .allTouchEvents) }
    }
}

struct HiddenPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView { BroadcastLauncher.shared.picker }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

struct StreamTab: View {
    @Binding var tab: Int
    @State private var destinations = Store.destinations
    @State private var activeId = Store.activeId
    @State private var prefs = Store.prefs
    // ponytail: "live" = screen is being captured (broadcast, recording or mirroring); the extension runs in
    // another process, so use an app-group heartbeat if this needs to be broadcast-specific.
    @State private var liveSince: Date?
    @State private var sceneDest: Destination?      // scene editor sheet, edits save live
    @State private var showSuperChat = false

    private var active: Destination? { destinations.first { $0.id == activeId } ?? destinations.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    StudioCard(active: active, liveSince: liveSince) { tab = 1 }
                        .padding(.top, 22)

                    section("Stream")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(icon: "speedometer", tint: .green,
                                 value: active.map { "\($0.videoBitrate / 1000)" } ?? "—",
                                 caption: prefs.adaptiveBitrate ? "kbps · adaptive" : "kbps · fixed")
                        StatTile(icon: "video.fill", tint: .blue,
                                 value: active.map { "\($0.height)p\($0.fps)" } ?? "—",
                                 caption: active.map { $0.hevc ? "HEVC" : "H.264" } ?? "Quality")
                        StatTile(icon: "timer", tint: .orange,
                                 value: active.map { $0.delaySeconds == 0 ? "Off" : "\($0.delaySeconds)s" } ?? "—",
                                 caption: "Stream delay")
                        StatTile(icon: "waveform", tint: .purple,
                                 value: ["Mic", "Game", "Mic + Game"][min(prefs.audioSource, 2)],
                                 caption: (active?.stereo ?? true) ? "Stereo · \((active?.audioBitrate ?? 128_000) / 1000)k" : "Mono")
                    }

                    section("Quick controls")
                    HStack(spacing: 12) {
                        QuickTile(icon: "record.circle", label: "Record", on: prefs.recordWhileStreaming, tint: .red) {
                            prefs.recordWhileStreaming.toggle()
                        }
                        QuickTile(icon: "speedometer", label: "Adaptive", on: prefs.adaptiveBitrate, tint: .green) {
                            prefs.adaptiveBitrate.toggle()
                        }
                        QuickTile(icon: "waveform", label: ["Mic", "Game", "Both"][min(prefs.audioSource, 2)], on: true,
                                  tint: .purple, detail: "Audio") {
                            prefs.audioSource = (prefs.audioSource + 1) % 3
                        }
                    }

                    // Scene & mixer: arrange layers on the real stream frame; edits reach the broadcast within a second.
                    if let active {
                        Button { sceneDest = active } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.3.group.fill").font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white).frame(width: 34, height: 34)
                                    .background(emberGradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scene & Audio Mixer").font(.body.weight(.semibold)).foregroundStyle(.primary)
                                    Text(liveSince != nil ? "Adjust layers and volume live" : sceneSummary(active))
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(PressScale())
                        .padding(.top, 12)
                    }

                    BreakCard(live: liveSince != nil, prefs: $prefs).padding(.top, 12)

                    // Super Chat alerts: paid messages from YouTube live chat, shown on stream.
                    Button { showSuperChat = true } label: {
                        HStack(spacing: 12) {
                            Text("$").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(LinearGradient(colors: [Color(red: 1, green: 0.79, blue: 0.16), Color(red: 0.96, green: 0.49, blue: 0),
                                                                    Color(red: 0.91, green: 0.12, blue: 0.39)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Super Chat alerts").font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(!prefs.superChat ? "Off · show paid YouTube messages on stream"
                                     : prefs.ytApiKey.isEmpty ? "On · add your YouTube key to connect"
                                     : "On · \(SuperChatCard.styles[min(max(prefs.alertStyle, 0), 3)]) style, \(prefs.alertSeconds) s")
                                    .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressScale())
                    .padding(.top, 12)

                    HStack(alignment: .lastTextBaseline) {
                        section("Channels")
                        Spacer()
                        Button("Manage") { tab = 1 }.font(.subheadline).padding(.trailing, 4)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(destinations) { d in channelCard(d) }
                            Button { tab = 1 } label: {
                                Image(systemName: "plus").font(.title3.weight(.semibold))
                                    .frame(width: 72, height: 88)
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(.separator)))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(EmberBackdrop())
            .background(HiddenPicker().frame(width: 1, height: 1).opacity(0.01))
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                destinations = Store.destinations; activeId = Store.activeId; prefs = Store.prefs
                if UIScreen.main.isCaptured, liveSince == nil { liveSince = Date() }
                if !UIScreen.main.isCaptured {                                      // stream ended while away
                    Store.liveSince = 0
                    Task { await LiveControls.end() }
                }
            }
            .onChange(of: prefs) { _, new in Store.prefs = new }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                liveSince = UIScreen.main.isCaptured ? Date() : nil
                // Stream controls in the Dynamic Island / Lock Screen while live (iOS's answer to a bubble).
                if liveSince != nil { LiveControls.start(channel: active?.name ?? "Live") }
                else { Task { await LiveControls.end() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSuperChat)) { _ in showSuperChat = true }
            .sheet(isPresented: $showSuperChat, onDismiss: { destinations = Store.destinations; prefs = Store.prefs }) {
                SuperChatSheet()
            }
            .sheet(item: $sceneDest, onDismiss: { destinations = Store.destinations; prefs = Store.prefs }) { dest in
                LiveSceneSheet(dest: dest)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("Brand").resizable().frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .ember.opacity(0.45), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Angra Streaming").font(.system(size: 28, weight: .bold)).tracking(-0.6)
                Text(liveSince != nil ? "You're live. Make it count."
                     : active == nil ? "Add a channel to get started" : "Ready when you are")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
    }

    private func section(_ title: String) -> some View {
        Text(title.uppercased()).font(.footnote).foregroundStyle(.secondary)
            .padding(.leading, 16).padding(.top, 28).padding(.bottom, 7)
    }

    private func channelCard(_ d: Destination) -> some View {
        let on = d.id == active?.id
        return Button {
            Store.activeId = d.id; activeId = d.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(platformOf(d.url).uppercased()).font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(Color.ember)
                    Spacer()
                    if on { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Color.ember) }
                }
                Text(d.name).font(.body.weight(.semibold)).lineLimit(1).foregroundStyle(.primary).padding(.top, 2)
                Text("\(d.height)p · \(d.fps) fps").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(width: 156, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(on ? Color.ember : Color(.separator), lineWidth: on ? 2 : 0.5))
        }
        .buttonStyle(PressScale())
        .disabled(liveSince != nil)
        .opacity(liveSince != nil && !on ? 0.4 : 1)
    }
}

/// The hero: a dark "studio" card that stays dark in both appearances, like a viewfinder.
struct StudioCard: View {
    let active: Destination?
    let liveSince: Date?
    let onAddChannel: () -> Void
    @State private var pulse = false

    var body: some View {
        let live = liveSince != nil
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(active.map { platformOf($0.url) }?.uppercased() ?? "NO CHANNEL")
                    .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(live ? Color.red : .white.opacity(0.45)).frame(width: 7, height: 7)
                        .opacity(live && pulse ? 0.25 : 1)
                        .animation(live ? .easeInOut(duration: 0.9).repeatForever() : .default, value: pulse)
                    Text(live ? "LIVE" : "OFFLINE").font(.caption.weight(.bold)).tracking(0.8)
                        .foregroundStyle(live ? Color.red : .white.opacity(0.45))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((live ? Color.red : .white).opacity(0.18), in: Capsule())
            }
            Text(active?.name ?? "No channel yet").font(.system(size: 22, weight: .semibold)).tracking(-0.4)
                .foregroundStyle(.white).lineLimit(1).padding(.top, 18)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let s = liveSince.map { max(0, Int(ctx.date.timeIntervalSince($0))) } ?? 0
                Text(String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
                    .font(.system(size: 52, weight: .light)).monospacedDigit().tracking(-1)
                    .foregroundStyle(.white.opacity(live ? 1 : 0.35))
            }
            Text(active.map { "\($0.width)×\($0.height) · \($0.fps) fps · \($0.videoBitrate / 1000) kbps" }
                 ?? "Add YouTube, Twitch, Kick, Facebook or any RTMP server")
                .font(.subheadline).foregroundStyle(.white.opacity(0.55))

            Button {
                if active == nil { onAddChannel() } else { BroadcastLauncher.shared.open() }
            } label: {
                Text(active == nil ? "Add a Channel" : live ? "End Stream" : "Go Live")
                    .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(active == nil ? AnyShapeStyle(Color.white.opacity(0.14))
                                  : live ? AnyShapeStyle(Color.red) : AnyShapeStyle(emberGradient))
                    }
                    .shadow(color: active == nil || live ? .clear : .ember.opacity(0.5), radius: 14, y: 6)
            }
            .buttonStyle(PressScale())
            .padding(.top, 20)
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.12), Color(red: 0.17, green: 0.08, blue: 0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 0.5))
        .shadow(color: (live ? Color.red : .ember).opacity(0.35), radius: 24, y: 10)
        .onAppear { pulse = true }
    }
}

/// At-a-glance tile with an iOS Settings-style coloured icon square.
/// Break screen: covers the stream while it keeps running (audio continues). Plain black with no name or
/// branding, or the user's own image / GIF fitted without stretching. Reaches the broadcast within a second.
struct BreakCard: View {
    let live: Bool
    @Binding var prefs: Prefs
    @State private var onBreak = Store.onBreak
    @State private var item: PhotosPickerItem?
    @State private var showPicker = false
    @State private var thumb: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "pause.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(onBreak ? Color.red : Color(white: 0.17), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Break screen").font(.body.weight(.semibold))
                    Text(onBreak ? "On air: viewers see your break screen"
                         : live ? "Cover the stream without ending it" : "Ready for when you go live")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button(onBreak ? "End" : "Start") { setBreak(!onBreak) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .tint(onBreak ? .red : .ember)
                    .disabled(!live)
            }
            HStack(spacing: 12) {
                // What viewers will see, at stream shape.
                ZStack {
                    Color.black
                    if let thumb { Image(uiImage: thumb).resizable().scaledToFit() }
                }
                .frame(width: 104, height: 58.5)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(.separator), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Break screen", selection: Binding(get: { !prefs.breakFile.isEmpty },
                                                              set: { custom in if custom { showPicker = true } else { setFile("") } })) {
                        Text("Black").tag(false); Text("My image").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if !prefs.breakFile.isEmpty { Button("Change image") { showPicker = true }.font(.subheadline) }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .photosPicker(isPresented: $showPicker, selection: $item, matching: .images)
        .onChange(of: item) { _, picked in
            Task {
                guard let picked, let data = try? await picked.loadTransferable(type: Data.self),
                      let file = saveImage(data, prefix: "break") else { return }
                setFile(file)
            }
        }
        .onAppear { onBreak = Store.onBreak; thumb = Store.overlayURL(prefs.breakFile).flatMap { loadPreview($0) } }
        .onChange(of: live) { _, isLive in if !isLive { onBreak = false } }
    }

    private func setBreak(_ on: Bool) {
        Store.onBreak = on; onBreak = on
        Task { await LiveControls.refresh() }          // keep the Live Activity button in step
    }

    private func setFile(_ file: String) {
        if file != prefs.breakFile, let old = Store.overlayURL(prefs.breakFile) { try? FileManager.default.removeItem(at: old) }
        prefs.breakFile = file                          // StreamTab saves prefs; the broadcast reloads within a second
        thumb = Store.overlayURL(file).flatMap { loadPreview($0) }
    }
}

/// Super Chat alerts: look, timing, placement and the YouTube connection, previewed on the stream frame with
/// the exact card the broadcast draws. Saves as you go; a running broadcast picks changes up within a second.
struct SuperChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var d = Store.active ?? Destination()
    @State private var prefs = Store.prefs
    @State private var tier = 4
    @State private var status = ""
    @State private var shown = false
    private var live: Bool { UIScreen.main.isCaptured }
    private let tierLabels = ["$1", "$2", "$5", "$10", "$20", "$50", "$100"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    stage.listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                } footer: {
                    Text("Exactly what viewers see. Colours follow YouTube's Super Chat tiers.")
                }
                Section("Preview amount") {
                    Picker("Amount", selection: $tier) {
                        ForEach(1...7, id: \.self) { Text(tierLabels[$0 - 1]).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Style") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<SuperChatCard.styles.count, id: \.self) { i in styleThumb(i) }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Toggle("Show Super Chats", isOn: $prefs.superChat)
                    Toggle("Show supporter's total", isOn: $prefs.alertShowTotal)
                    Picker("On screen for", selection: $prefs.alertSeconds) {
                        ForEach([5, 8, 12, 20], id: \.self) { Text("\($0) s").tag($0) }
                    }
                    NavigationLink("Position & size") { SceneEditorView(d: $d, startLayer: 2) }
                    Button(live ? "Send test alert" : "Go live to send a test") { Store.testAlertTier = tier }
                        .disabled(!live)
                } header: { Text("On stream") } footer: {
                    Text("Several at once queue up and play one after another.")
                }
                Section {
                    TextField("@handle or live link", text: $d.ytSource)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("YouTube Data API key", text: $prefs.ytApiKey)
                    if live, !status.isEmpty {
                        Label(status, systemImage: status.hasPrefix("Connected") ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.footnote)
                    }
                } header: { Text("YouTube") } footer: {
                    Text("Super Chats and Super Stickers are read from your live chat with the official YouTube Data API, using your own free key: in Google Cloud Console create a project, enable \"YouTube Data API v3\", then Credentials → Create credentials → API key. The key stays on this device. A key's free daily quota covers about 2–4 hours of live chat. The channel applies to \"\(d.name)\".")
                }
            }
            .scrollContentBackground(.hidden)
            .background(EmberBackdrop())
            .navigationTitle("Super Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
        }
        .tint(.ember)
        .onAppear { replay() }
        .onChange(of: prefs) { _, p in Store.prefs = p }
        .onChange(of: d) { _, new in
            var list = Store.destinations
            if let i = list.firstIndex(where: { $0.id == new.id }) { list[i] = new; Store.destinations = list }
        }
        .onChange(of: prefs.alertStyle) { _, _ in replay() }
        .onChange(of: prefs.alertShowTotal) { _, _ in replay() }
        .onChange(of: tier) { _, _ in replay() }
        .task {
            while !Task.isCancelled {
                status = Store.superChatStatus
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// Replays the entrance whenever the look changes, the way it arrives on stream.
    private func replay() {
        shown = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.05)) { shown = true }
    }

    private var stage: some View {
        let aspect = Double(d.canvas.width / d.canvas.height)
        let img = SuperChatCard.render(.sample(tier: tier), style: prefs.alertStyle, showTotal: prefs.alertShowTotal)
        return GeometryReader { geo in
            let W = Double(geo.size.width), H = Double(geo.size.height)
            let cw = d.alertW * W, ch = cw * Double(img.size.height / img.size.width)
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.11, green: 0.16, blue: 0.29), Color(red: 0.23, green: 0.12, blue: 0.36),
                                        Color(red: 0.48, green: 0.16, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(uiImage: img).resizable()
                    .frame(width: cw, height: ch)
                    .scaleEffect(shown ? 1 : 0.9)
                    .opacity(shown ? 1 : 0)
                    .offset(x: d.alertX * W - cw / 2, y: d.alertY * H - ch / 2 + (shown ? 0 : 14))
                HStack(spacing: 5) {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Text("PREVIEW").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(.white)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.black.opacity(0.8), in: Capsule())
                .padding(10)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func styleThumb(_ i: Int) -> some View {
        let on = prefs.alertStyle == i
        return Button { prefs.alertStyle = i } label: {
            VStack(spacing: 6) {
                Image(uiImage: SuperChatCard.render(.sample(tier: tier), style: i, showTotal: false))
                    .resizable().scaledToFit()
                    .padding(8)
                    .frame(width: 150, height: 96)
                    .background(LinearGradient(colors: [Color(red: 0.09, green: 0.09, blue: 0.16), Color(red: 0.16, green: 0.09, blue: 0.19)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(on ? Color.ember : Color(.separator), lineWidth: on ? 2 : 0.5))
                Text(SuperChatCard.styles[i]).font(.subheadline.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? Color.ember : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let icon: String, tint: Color, value: String, caption: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(value).font(.system(size: 22, weight: .semibold)).monospacedDigit().tracking(-0.5)
                .lineLimit(1).minimumScaleFactor(0.7).padding(.top, 12)
            Text(caption).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Control Center-style square toggle.
struct QuickTile: View {
    let icon: String, label: String, on: Bool, tint: Color
    var detail: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(on ? Color.white.opacity(0.22) : Color(.tertiarySystemFill), in: Circle())
                Spacer(minLength: 0)
                Text(label).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(detail ?? (on ? "On" : "Off")).font(.footnote).opacity(0.7)
            }
            .foregroundStyle(on ? Color.white : Color.primary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1, contentMode: .fit)
            .background(on ? AnyShapeStyle(tint) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScale())
        .sensoryFeedback(.selection, trigger: on)
    }
}

// MARK: - Channels

func summary(_ d: Destination) -> String {
    var parts = [platformOf(d.url), "\(d.height)p", "\(d.fps) fps", "\(d.videoBitrate / 1000) kbps"]
    if d.hevc { parts.append("HEVC") }
    if d.delaySeconds > 0 { parts.append("\(d.delaySeconds)s delay") }
    return parts.joined(separator: " · ")
}

struct ChannelsTab: View {
    @State private var destinations = Store.destinations
    @State private var activeId = Store.activeId
    @State private var editing: Destination?
    @State private var showEditor = false
    @State private var editMode = EditMode.inactive
    @State private var selected = Set<String>()
    @State private var moving: Destination?
    @State private var confirmDelete = false

    /// Display order: pinned first, each group in saved order. Positions 1...N refer to this order.
    private var ordered: [Destination] { destinations.filter(\.pinned) + destinations.filter { !$0.pinned } }

    var body: some View {
        NavigationStack {
            List(selection: $selected) {
                if destinations.isEmpty {
                    Text("No channels yet. Tap + to add YouTube, Twitch, Kick, Facebook or a custom RTMP URL. Make as many profiles as you like, e.g. one YouTube channel per game.")
                        .font(.subheadline).foregroundStyle(.secondary).listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { i, d in row(i, d) }
                            .onMove { from, to in
                                guard from.count == 1, let s = from.first else { return }
                                move(ordered[s].id, to: to > s ? to - 1 : to)
                            }
                    } header: {
                        Text(editMode.isEditing ? "Swipe down the circles to select · drag ≡ to reorder" : "Tap to make active · tap the number to move")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(EmberBackdrop())
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !destinations.isEmpty {
                        Button(editMode.isEditing ? "Done" : "Select") {
                            withAnimation { editMode = editMode.isEditing ? .inactive : .active; selected = [] }
                        }
                        .fontWeight(editMode.isEditing ? .semibold : .regular)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !editMode.isEditing { Button { editing = nil; showEditor = true } label: { Image(systemName: "plus") } }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if editMode.isEditing {
                        Button("Pin") { setPinned(true) }.disabled(selected.isEmpty)
                        Spacer()
                        Button("Unpin") { setPinned(false) }.disabled(selected.isEmpty)
                        Spacer()
                        Button(selected.isEmpty ? "Delete" : "Delete (\(selected.count))", role: .destructive) { confirmDelete = true }
                            .disabled(selected.isEmpty)
                    }
                }
            }
            .toolbar(editMode.isEditing ? .visible : .hidden, for: .bottomBar)
            .confirmationDialog("Delete \(selected.count) channel\(selected.count == 1 ? "" : "s")?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete(selected); selected = [] }
            } message: {
                Text("Their settings, scenes and overlay copies are removed from the app. This can't be undone.")
            }
            .onAppear { destinations = Store.destinations; activeId = Store.activeId }
            .sheet(isPresented: $showEditor) {
                ChannelEditor(existing: editing) { saved in
                    if let i = destinations.firstIndex(where: { $0.id == saved.id }) { destinations[i] = saved }
                    else { destinations.append(saved) }
                    persist()
                    if Store.activeId == nil { Store.activeId = saved.id; activeId = saved.id }
                    showEditor = false
                }
            }
            .sheet(item: $moving) { m in
                PositionSheet(name: m.name, current: (ordered.firstIndex { $0.id == m.id } ?? 0) + 1, count: ordered.count) { pos in
                    move(m.id, to: pos - 1)
                }
            }
        }
    }

    private func row(_ i: Int, _ d: Destination) -> some View {
        HStack(spacing: 12) {
            if !editMode.isEditing {
                // Position badge: tap for the number wheel to move this channel anywhere.
                Button { moving = d } label: {
                    Text("\(i + 1)").font(.footnote.weight(.semibold)).monospacedDigit()
                        .frame(minWidth: 34, minHeight: 26)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.borderless).tint(.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if d.pinned { Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.ember) }
                    Text(d.name).font(.body.weight(.semibold)).lineLimit(1)
                }
                Text(summary(d)).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if !editMode.isEditing {
                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.ember)
                    .opacity(d.id == (activeId ?? ordered.first?.id) ? 1 : 0)
                Button("Edit") { editing = d; showEditor = true }.buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !editMode.isEditing { Store.activeId = d.id; activeId = d.id } }
        .swipeActions(edge: .leading) {
            Button { togglePin(d.id) } label: {
                Label(d.pinned ? "Unpin" : "Pin", systemImage: d.pinned ? "star.slash" : "star")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete([d.id]) } label: { Label("Delete", systemImage: "trash") }
            Button { moving = d } label: { Label("Move", systemImage: "arrow.up.arrow.down") }.tint(.indigo)
        }
    }

    private func persist() { destinations = ordered; Store.destinations = destinations }

    private func togglePin(_ id: String) {
        if let i = destinations.firstIndex(where: { $0.id == id }) { destinations[i].pinned.toggle() }
        persist()
    }

    private func setPinned(_ on: Bool) {
        for i in destinations.indices where selected.contains(destinations[i].id) { destinations[i].pinned = on }
        selected = []; persist()
    }

    /// Re-inserts a channel at display index `to`. Landing among the pinned channels pins it; below them unpins it.
    private func move(_ id: String, to: Int) {
        var rest = ordered
        guard let from = rest.firstIndex(where: { $0.id == id }) else { return }
        var m = rest.remove(at: from)
        let pinnedBefore = rest.filter(\.pinned).count
        let to = min(max(to, 0), rest.count)
        m.pinned = to < pinnedBefore || (m.pinned && to == pinnedBefore)
        rest.insert(m, at: to)
        destinations = rest; Store.destinations = rest
    }

    private func delete(_ ids: Set<String>) {
        for d in destinations where ids.contains(d.id) {
            if let f = Store.overlayURL(d.overlayFile) { try? FileManager.default.removeItem(at: f) }
        }
        destinations.removeAll { ids.contains($0.id) }
        persist()
        if let a = activeId, ids.contains(a) { activeId = destinations.first?.id; Store.activeId = activeId }
        if destinations.isEmpty { editMode = .inactive }
    }
}

/// iOS number wheel: spin to the new position (e.g. take entry 25 straight to 1).
struct PositionSheet: View {
    let name: String
    let count: Int
    let onMove: (Int) -> Void
    @State private var pos: Int
    @Environment(\.dismiss) private var dismiss

    init(name: String, current: Int, count: Int, onMove: @escaping (Int) -> Void) {
        self.name = name; self.count = count; self.onMove = onMove
        _pos = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 4) {
                Picker("Position", selection: $pos) {
                    ForEach(1...max(count, 1), id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                Text("Moving above the last pinned channel pins it.").font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Move “\(name)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Move") { onMove(pos); dismiss() }.fontWeight(.semibold) }
            }
        }
        .tint(.ember)
        .presentationDetents([.height(320)])
    }
}

struct ChannelEditor: View {
    let existing: Destination?
    let onSave: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var d: Destination

    /// Only sizes the screen can fill: capture is never upscaled (no enhancers). Every iOS 17 device (A12+)
    /// hardware-encodes H.264 and HEVC at 1080p60, so the screen is the only real limit.
    private var resolutions: [(Int, Int)] {
        let all = [(640, 360), (854, 480), (1280, 720), (1920, 1080)]
        let short = Int(min(UIScreen.main.nativeBounds.width, UIScreen.main.nativeBounds.height))
        let fit = all.filter { $0.1 <= short }
        return fit.isEmpty ? [all[0]] : fit
    }
    private let audioBitrates = [96_000, 128_000, 160_000, 192_000, 256_000]
    private let sampleRates = [44_100, 48_000]
    private let platforms = [("YouTube", "rtmps://a.rtmp.youtube.com/live2"), ("Twitch", "rtmp://live.twitch.tv/app"),
                             ("Facebook", "rtmps://live-api-s.facebook.com:443/rtmp/"), ("Kick", ""), ("Custom", "")]
    private var valid: Bool { !d.name.isEmpty && d.url.hasPrefix("rtmp") }

    init(existing: Destination?, onSave: @escaping (Destination) -> Void) {
        self.existing = existing; self.onSave = onSave
        _d = State(initialValue: existing ?? Destination())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(platforms.indices, id: \.self) { i in
                                let p = platforms[i]
                                Button(p.0) {
                                    if d.name.isEmpty { d.name = p.0 }
                                    if !p.1.isEmpty { d.url = p.1 }
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: { Text("Platform") } footer: {
                    Text("Picks the server URL. Paste your stream key from the platform's dashboard.")
                }
                Section("Destination") {
                    TextField("Name", text: $d.name)
                    TextField("rtmps://…", text: $d.url).keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
                    SecureField("Stream key", text: $d.key)
                }
                Section("Video") {
                    Picker("Resolution", selection: Binding(
                        get: { d.height },
                        set: { h in if let r = resolutions.first(where: { $0.1 == h }) { d.width = r.0; d.height = r.1 } })) {
                        ForEach(resolutions.map { $0.1 }, id: \.self) { Text("\($0)p").tag($0) }
                    }
                    .onAppear {   // a channel made on a bigger-screened device snaps to this phone's maximum
                        if !resolutions.contains(where: { $0.1 == d.height }), let r = resolutions.last { d.width = r.0; d.height = r.1 }
                    }
                    Picker("Frame rate", selection: $d.fps) { Text("30 fps").tag(30); Text("60 fps").tag(60) }
                        .pickerStyle(.segmented)
                    Picker("Codec", selection: $d.hevc) { Text("H.264").tag(false); Text("HEVC").tag(true) }
                        .pickerStyle(.segmented)
                    Picker("Keyframe", selection: $d.keyframeSeconds) {
                        Text("1s").tag(1); Text("2s").tag(2); Text("4s").tag(4)
                    }
                    Picker("Orientation", selection: $d.portrait) {
                        Text("Landscape").tag(false); Text("Portrait").tag(true)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Video bitrate", value: "\(d.videoBitrate / 1000) kbps · CBR")
                        Slider(value: Binding(get: { Double(d.videoBitrate) },
                                              set: { d.videoBitrate = Int(($0 / 100_000).rounded()) * 100_000 }),
                               in: 800_000...12_000_000)
                    }
                    Stepper("Stream delay \(d.delaySeconds)s", value: $d.delaySeconds, in: 0...600, step: 5)
                }
                Section("Audio") {
                    Picker("Audio bitrate", selection: $d.audioBitrate) {
                        ForEach(audioBitrates, id: \.self) { Text("\($0 / 1000)k").tag($0) }
                    }
                    Picker("Sample rate", selection: $d.sampleRate) {
                        ForEach(sampleRates, id: \.self) { Text("\($0 / 1000)kHz").tag($0) }
                    }
                    Toggle("Stereo", isOn: $d.stereo)
                }
                Section {
                    NavigationLink { SceneEditorView(d: $d) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scene & Audio Mixer")
                            Text(sceneSummary(d)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: { Text("Scene & audio") } footer: {
                    Text("Arrange your screen and overlay on the real stream frame, and set mic/game volume.")
                }
            }
            .navigationTitle(existing == nil ? "New Channel" : "Edit Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(d) }.fontWeight(.semibold).disabled(!valid)
                }
            }
        }
        .tint(.ember)
    }
}

// MARK: - Settings

struct SettingsTab: View {
    @State private var prefs = Store.prefs
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ThemePicker(selected: $prefs.theme)
                } header: { Text("Theme · \(Theme.byId(prefs.theme).name)") }
                Section {
                    Picker("Capture", selection: $prefs.audioSource) {
                        Text("Mic").tag(0); Text("Game").tag(1); Text("Both").tag(2)
                    }.pickerStyle(.segmented)
                } header: { Text("Audio source") } footer: {
                    Text("Mic uses the iPhone microphone, or a connected Bluetooth, wired or USB mic.")
                }
                Section {
                    Toggle("Adaptive bitrate", isOn: $prefs.adaptiveBitrate)
                } header: { Text("Network") } footer: {
                    Text("Drops quality automatically when upload can't keep up, instead of dropping the stream.")
                }
                Section {
                    Toggle("Record while streaming", isOn: $prefs.recordWhileStreaming)
                } header: { Text("Recording") } footer: {
                    Text("Uses the active channel's resolution and bitrate.")
                }
                Section {
                    ForEach(0..<ActivityAction.count, id: \.self) { i in
                        Picker("Button \(i + 1)", selection: slotBinding(i)) {
                            ForEach(ActivityAction.allCases) { a in Label(a.label, systemImage: a.symbol).tag(a) }
                        }
                    }
                } header: { Text("Live Activity controls") } footer: {
                    Text("iOS has no floating bubble over other apps, so your stream controls live in the Dynamic Island and on the Lock Screen while you're live. Pick the three buttons; choosing one that's already used swaps them.")
                }
                Section {
                    Label("The red recording indicator is always shown by iOS while broadcasting.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(EmberBackdrop())
            .navigationTitle("Settings")
            .onAppear { prefs = Store.prefs }
            .onChange(of: prefs) { _, new in Store.prefs = new }
            .onChange(of: prefs.theme) { _, id in
                Theme.current = Theme.byId(id)
                NotificationCenter.default.post(name: .themeChanged, object: nil)
            }
        }
    }

    /// Slot i of the Live Activity; picking an action that's already in another slot swaps the two.
    private func slotBinding(_ i: Int) -> Binding<ActivityAction> {
        Binding(get: { ActivityAction.slots(prefs.activitySlots)[i] }, set: { a in
            var s = ActivityAction.slots(prefs.activitySlots)
            if let j = s.firstIndex(of: a) { s[j] = s[i] }
            s[i] = a
            prefs.activitySlots = s.map(\.rawValue)
        })
    }
}
