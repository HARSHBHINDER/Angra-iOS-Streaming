import ReplayKit
import SwiftUI

@main
struct LivePipeApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

/// Apple-native tabbed UI mirroring the Android app: Stream / Channels / Settings.
struct RootView: View {
    var body: some View {
        TabView {
            StreamTab().tabItem { Label("Stream", systemImage: "dot.radiowaves.left.and.right") }
            ChannelsTab().tabItem { Label("Channels", systemImage: "slider.horizontal.3") }
            SettingsTab().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.blue)
    }
}

struct StreamTab: View {
    @State private var active = Store.active
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                // ReplayKit broadcasts can only be started by the system picker; this is the Go Live control.
                BroadcastButton().frame(width: 180, height: 180)
                Text(active == nil ? "Add a channel first" : "Tap, choose LivePipe, Start Broadcast")
                    .font(.footnote).foregroundStyle(.secondary)
                if let a = active {
                    GroupBox("Active channel") {
                        LabeledContent(a.name, value: "\(a.height)p · \(a.fps)fps")
                    }.padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("Angra iOS Streaming")
            .onAppear { active = Store.active }
        }
    }
}

struct ChannelsTab: View {
    @State private var destinations = Store.destinations
    @State private var editing: Destination?
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(destinations) { d in
                    Button { Store.activeId = d.id; destinations = Store.destinations } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(d.name).font(.headline)
                                Text("\(d.height)p · \(d.fps)fps · \(d.videoBitrate / 1000)kbps")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if d.id == Store.activeId { Text("Active").foregroundStyle(.green) }
                            Button("Edit") { editing = d; showEditor = true }.buttonStyle(.borderless)
                        }
                    }
                }
                .onDelete { idx in
                    destinations.remove(atOffsets: idx); Store.destinations = destinations
                }
            }
            .navigationTitle("Channels")
            .toolbar { Button { editing = nil; showEditor = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $showEditor) {
                ChannelEditor(existing: editing) { saved in
                    if let i = destinations.firstIndex(where: { $0.id == saved.id }) { destinations[i] = saved }
                    else { destinations.append(saved) }
                    Store.destinations = destinations
                    if Store.activeId == nil { Store.activeId = saved.id }
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

    init(existing: Destination?, onSave: @escaping (Destination) -> Void) {
        self.existing = existing; self.onSave = onSave
        _d = State(initialValue: existing ?? Destination())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    TextField("Name", text: $d.name)
                    TextField("RTMP/RTMPS URL", text: $d.url).keyboardType(.URL).autocorrectionDisabled()
                    SecureField("Stream key", text: $d.key)
                }
                Section("Video") {
                    Picker("Resolution", selection: Binding(
                        get: { d.height },
                        set: { h in if let r = resolutions.first(where: { $0.1 == h }) { d.width = r.0; d.height = r.1 } })) {
                        ForEach(resolutions.map { $0.1 }, id: \.self) { Text("\($0)p").tag($0) }
                    }
                    Picker("Frame rate", selection: $d.fps) { Text("30 fps").tag(30); Text("60 fps").tag(60) }
                    Picker("Codec", selection: $d.hevc) { Text("H.264").tag(false); Text("HEVC").tag(true) }
                    Picker("Keyframe", selection: $d.keyframeSeconds) {
                        Text("1s").tag(1); Text("2s").tag(2); Text("4s").tag(4)
                    }
                    Picker("Orientation", selection: $d.portrait) {
                        Text("Landscape").tag(false); Text("Portrait").tag(true)
                    }
                    Stepper("Stream delay \(d.delaySeconds)s", value: $d.delaySeconds, in: 0...600, step: 5)
                    Stepper("Video \(d.videoBitrate / 1000) kbps · CBR", value: $d.videoBitrate, in: 800_000...12_000_000, step: 100_000)
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
            .navigationTitle(existing == nil ? "New channel" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if !d.name.isEmpty && d.url.hasPrefix("rtmp") { onSave(d) } }
                }
            }
        }
    }
}

struct SettingsTab: View {
    @State private var prefs = Store.prefs
    var body: some View {
        NavigationStack {
            Form {
                Section("Audio source") {
                    Picker("Capture", selection: $prefs.audioSource) {
                        Text("Mic").tag(0); Text("Game").tag(1); Text("Both").tag(2)
                    }.pickerStyle(.segmented)
                }
                Section("Network") {
                    Toggle("Adaptive bitrate", isOn: $prefs.adaptiveBitrate)
                    Text("Drops quality automatically when upload can't keep up.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Recording") {
                    Toggle("Record while streaming", isOn: $prefs.recordWhileStreaming)
                    Text("Recording uses the active channel's resolution and bitrate.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("No floating bubble on iOS — the system has no cross-app overlay. The red recording indicator is always shown by the OS while broadcasting.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: prefs) { _, new in Store.prefs = new }
        }
    }
}

/// Wraps the system broadcast picker as the round Go Live button.
struct BroadcastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 180, height: 180))
        v.preferredExtension = "dev.livepipe.app.broadcast"
        v.showsMicrophoneButton = true
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
