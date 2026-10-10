import PhotosUI
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
    @State private var sceneDest: Destination?      // scene editor sheet, edits save live

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
                if !UIScreen.main.isCaptured { Task { await LiveControls.end() } }   // stream ended while away
            }
            .onChange(of: prefs) { _, new in Store.prefs = new }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                liveSince = UIScreen.main.isCaptured ? Date() : nil
                // Stream controls in the Dynamic Island / Lock Screen while live (iOS's answer to a bubble).
                if liveSince != nil { LiveControls.start(channel: active?.name ?? "Live") }
                else { Task { await LiveControls.end() } }
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
