import ReplayKit
import SwiftUI

@main
struct LivePipeApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

// MARK: - Brand

/// Angra ember: the oni icon's flame, used as the app tint and for the Go Live gradient.
extension Color {
    static let ember = Color(red: 0.95, green: 0.33, blue: 0.18)
}
let emberGradient = LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.23), Color(red: 1, green: 0.54, blue: 0)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)

/// Grouped background with a soft ember glow behind the large title — the app's signature.
struct EmberBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        ZStack {
            Color(.systemGroupedBackground)
            RadialGradient(colors: [Color(red: 1, green: 0.23, blue: 0.19).opacity(dark ? 0.42 : 0.20), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(red: 1, green: 0.54, blue: 0).opacity(dark ? 0.22 : 0.12), .clear],
                           center: UnitPoint(x: 0, y: 0.12), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
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
    var body: some View {
        TabView(selection: $tab) {
            StreamTab(tab: $tab).tag(0).tabItem { Label("Stream", systemImage: "dot.radiowaves.left.and.right") }
            ChannelsTab().tag(1).tabItem { Label("Channels", systemImage: "list.bullet") }
            SettingsTab().tag(2).tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.ember)
    }
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
            }
            .onChange(of: prefs) { _, new in Store.prefs = new }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                liveSince = UIScreen.main.isCaptured ? Date() : nil
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

    var body: some View {
        NavigationStack {
            List {
                if destinations.isEmpty {
                    Text("No channels yet. Tap + to add YouTube, Twitch, Kick, Facebook or a custom RTMP URL.")
                        .font(.subheadline).foregroundStyle(.secondary).listRowBackground(Color.clear)
                } else {
                    Section("Tap to make active") {
                        ForEach(destinations) { d in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.ember)
                                    .opacity(d.id == (activeId ?? destinations.first?.id) ? 1 : 0)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.name).font(.body.weight(.semibold))
                                    Text(summary(d)).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Edit") { editing = d; showEditor = true }.buttonStyle(.borderless)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { Store.activeId = d.id; activeId = d.id }
                        }
                        .onDelete { idx in
                            destinations.remove(atOffsets: idx); Store.destinations = destinations
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(EmberBackdrop())
            .navigationTitle("Channels")
            .toolbar { Button { editing = nil; showEditor = true } label: { Image(systemName: "plus") } }
            .onAppear { destinations = Store.destinations; activeId = Store.activeId }
            .sheet(isPresented: $showEditor) {
                ChannelEditor(existing: editing) { saved in
                    if let i = destinations.firstIndex(where: { $0.id == saved.id }) { destinations[i] = saved }
                    else { destinations.append(saved) }
                    Store.destinations = destinations
                    if Store.activeId == nil { Store.activeId = saved.id; activeId = saved.id }
                    showEditor = false
                }
            }
        }
    }
}

struct ChannelEditor: View {
    let existing: Destination?
    let onSave: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var d: Destination

    private let resolutions = [(640, 360), (854, 480), (1280, 720), (1920, 1080)]
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
                    Label("The red recording indicator is always shown by iOS while broadcasting. iOS has no floating bubble (no cross-app overlays).",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(EmberBackdrop())
            .navigationTitle("Settings")
            .onAppear { prefs = Store.prefs }
            .onChange(of: prefs) { _, new in Store.prefs = new }
        }
    }
}
