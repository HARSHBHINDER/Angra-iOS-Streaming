import ImageIO
import PhotosUI
import SwiftUI

func sceneSummary(_ d: Destination) -> String {
    [d.screenFit ? "Fit" : "Fill", "zoom \(Int(d.screenZoom * 100))%", d.overlayFile.isEmpty ? "no overlay" : "overlay"]
        .joined(separator: " · ")
}

/// OBS-style scene editor. The canvas is the real stream shape (e.g. 16:9 for YouTube), not the phone's.
/// Tap a layer to select it, drag to move, pinch to zoom/resize. Geometry is ScreenView, the same math the
/// broadcast extension composites with, so what you arrange here is what viewers get.
struct SceneEditorView: View {
    @Binding var d: Destination
    @State private var prefs = Store.prefs
    @State private var layer = 0                    // 0 screen, 1 overlay
    @State private var pickerItem: PhotosPickerItem?
    @State private var overlayImage: UIImage?
    @State private var base: Destination?           // gesture baseline (translation/magnification are cumulative)

    private var sourceAspect: Double {
        let b = UIScreen.main.bounds
        let long = Double(max(b.width, b.height)), short = Double(min(b.width, b.height))
        return d.portrait ? short / long : long / short   // games run landscape in a landscape stream
    }
    private var canvasAspect: Double { Double(d.canvas.width / d.canvas.height) }

    var body: some View {
        Form {
            Section {
                canvas.listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            } footer: {
                Text("\(Int(d.canvas.width))×\(Int(d.canvas.height)) — exactly what your viewers see. Tap a layer, drag to move, pinch to resize.")
            }
            Section("Layer") {
                Picker("Layer", selection: $layer) { Text("Screen").tag(0); Text("Overlay").tag(1) }.pickerStyle(.segmented)
            }
            if layer == 0 {
                Section("Screen") {
                    Picker("Mode", selection: $d.screenFit) {
                        Text("Fill (no borders)").tag(false); Text("Fit whole screen").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: d.screenFit) { _, _ in d.screenPanX = 0; d.screenPanY = 0 }
                    VStack(alignment: .leading) {
                        LabeledContent("Zoom", value: "\(Int(d.screenZoom * 100))%")
                        Slider(value: $d.screenZoom, in: 1...ScreenView.maxZoom)
                    }
                    Button("Reset position and zoom") { d.screenZoom = 1; d.screenPanX = 0; d.screenPanY = 0 }
                }
            } else {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(d.overlayFile.isEmpty ? "Choose overlay image" : "Change overlay image", systemImage: "photo")
                    }
                    if !d.overlayFile.isEmpty {
                        VStack(alignment: .leading) {
                            LabeledContent("Size", value: "\(Int(d.overlayW * 100))% of width")
                            Slider(value: $d.overlayW, in: 0.05...2)
                        }
                        Button("Fill canvas") { d.overlayX = 0.5; d.overlayY = 0.5; d.overlayW = 1 }
                        Button("Remove overlay", role: .destructive) {
                            if let old = Store.overlayURL(d.overlayFile) { try? FileManager.default.removeItem(at: old) }
                            d.overlayFile = ""; overlayImage = nil
                        }
                    }
                } header: { Text("Overlay") } footer: {
                    Text("Any image, including animated GIFs. It keeps its own shape and may hang past the edges; only the part inside the frame is streamed. A copy is kept in the app, so the original can be deleted.")
                }
            }
            Section {
                mixerRow("Microphone", "mic.fill", $prefs.micVolume, prefs.audioSource != Prefs.audioGame)
                mixerRow("Game & system", "speaker.wave.2.fill", $prefs.gameVolume, prefs.audioSource != Prefs.audioMic)
            } header: { Text("Audio mixer") } footer: {
                Text("Changes reach a live broadcast within a second. Audio source (Mic / Game / Both) is in Settings.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(EmberBackdrop())
        .navigationTitle("Scene")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prefs = Store.prefs
            overlayImage = Store.overlayURL(d.overlayFile).flatMap { loadPreview($0) }
        }
        .onChange(of: prefs) { _, p in Store.prefs = p }
        .onChange(of: pickerItem) { _, item in Task { await loadOverlay(item) } }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let W = Double(geo.size.width), H = Double(geo.size.height)
            let v = ScreenView(sourceAspect: sourceAspect, canvasAspect: canvasAspect, fit: d.screenFit,
                               zoom: d.screenZoom, panX: d.screenPanX, panY: d.screenPanY)
            let r = v.contentRect
            ZStack(alignment: .topLeading) {
                Color.black
                // Screen layer: stylised stand-in for the gameplay (the real frame only exists once live).
                LinearGradient(colors: [Color(red: 0.11, green: 0.16, blue: 0.29), Color(red: 0.23, green: 0.12, blue: 0.36),
                                        Color(red: 0.48, green: 0.16, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "gamecontroller.fill").font(.title2)
                            Text("Your screen").font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(width: r.w * W, height: r.h * H)
                    .offset(x: r.l * W, y: r.t * H)
                if let img = overlayImage, !d.overlayFile.isEmpty, img.size.width > 0 {
                    let ow = d.overlayW * W
                    let oh = ow * Double(img.size.height / img.size.width)
                    AnimatedImageView(image: img)
                        .frame(width: ow, height: oh)
                        .overlay(Rectangle().stroke(layer == 1 ? Color.ember : .clear, lineWidth: 2))
                        .offset(x: d.overlayX * W - ow / 2, y: d.overlayY * H - oh / 2)
                }
            }
            .frame(width: W, height: H)
            .clipped()
            .contentShape(Rectangle())
            .gesture(drag(W: W, H: H).simultaneously(with: pinch))
            .simultaneousGesture(SpatialTapGesture().onEnded { t in select(t.location, W: W, H: H) })
        }
        .aspectRatio(canvasAspect, contentMode: .fit)
        .frame(maxHeight: 440)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(layer == 0 ? Color.ember : Color(.separator), lineWidth: layer == 0 ? 2 : 0.5))
    }

    private func select(_ p: CGPoint, W: Double, H: Double) {
        let x = Double(p.x) / W, y = Double(p.y) / H
        if let img = overlayImage, !d.overlayFile.isEmpty, img.size.width > 0 {
            let oh = d.overlayW * W * Double(img.size.height / img.size.width) / H
            if abs(x - d.overlayX) < d.overlayW / 2, abs(y - d.overlayY) < oh / 2 { layer = 1; return }
        }
        layer = 0
    }

    private func drag(W: Double, H: Double) -> some Gesture {
        DragGesture()
            .onChanged { g in
                if base == nil { base = d }
                guard let b = base else { return }
                let dx = Double(g.translation.width) / W, dy = Double(g.translation.height) / H
                if layer == 1 {
                    d.overlayX = min(max(b.overlayX + dx, -0.5), 1.5); d.overlayY = min(max(b.overlayY + dy, -0.5), 1.5)
                } else {
                    // Move the window opposite the drag so the content follows the finger.
                    let v = ScreenView(sourceAspect: sourceAspect, canvasAspect: canvasAspect, fit: b.screenFit,
                                       zoom: d.screenZoom, panX: b.screenPanX, panY: b.screenPanY)
                    d.screenPanX = ScreenView.pan(centre: v.cx - dx / v.z, range: v.rx)
                    d.screenPanY = ScreenView.pan(centre: v.cy - dy / v.z, range: v.ry)
                }
            }
            .onEnded { _ in base = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { m in
                if base == nil { base = d }
                guard let b = base else { return }
                let k = Double(m.magnification)
                if layer == 1 { d.overlayW = min(max(b.overlayW * k, 0.05), 2) }
                else { d.screenZoom = min(max(b.screenZoom * k, 1), ScreenView.maxZoom) }
            }
            .onEnded { _ in base = nil }
    }

    // MARK: Overlay + mixer

    /// Copies the picked image into the app group (the original can then be deleted). Animated GIFs are kept
    /// as-is; stills are downscaled to ≤1920 px PNG so the memory-capped extension stays safe. A new file name
    /// each time lets a live broadcast notice the change.
    private func loadOverlay(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let file: String, bytes: Data
        if CGImageSourceGetCount(src) > 1 {
            file = "overlay_\(d.id)_\(stamp).gif"; bytes = data
        } else {
            guard let cg = AnimatedImage.image(src, 0, maxPixels: 1920), let png = UIImage(cgImage: cg).pngData() else { return }
            file = "overlay_\(d.id)_\(stamp).png"; bytes = png
        }
        guard let url = Store.overlayURL(file) else { return }
        try? bytes.write(to: url, options: .atomic)
        if let old = Store.overlayURL(d.overlayFile) { try? FileManager.default.removeItem(at: old) }
        overlayImage = loadPreview(url); d.overlayFile = file; layer = 1
    }

    private func mixerRow(_ title: String, _ icon: String, _ value: Binding<Double>, _ enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(enabled ? Color.ember : Color(.systemGray3), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title)
                Spacer()
                Text(!enabled ? "Off" : value.wrappedValue == 0 ? "Muted" : "\(Int(value.wrappedValue * 100))%")
                    .foregroundStyle(.secondary).monospacedDigit()
                Button { value.wrappedValue = value.wrappedValue == 0 ? 1 : 0 } label: {
                    Image(systemName: value.wrappedValue == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!enabled)
            }
            Slider(value: value, in: 0...1.5).disabled(!enabled)
        }
        .padding(.vertical, 4)
    }
}

/// Scene editor opened from the Stream tab: every change is saved immediately, so a running broadcast
/// (which re-reads the shared settings each second) picks it up live — the OBS way.
struct LiveSceneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var d: Destination
    init(dest: Destination) { _d = State(initialValue: dest) }

    var body: some View {
        NavigationStack {
            SceneEditorView(d: $d)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
                }
        }
        .tint(.ember)
        .onChange(of: d) { _, new in
            var list = Store.destinations
            if let i = list.firstIndex(where: { $0.id == new.id }) { list[i] = new; Store.destinations = list }
        }
    }
}

/// Editor preview of an overlay; GIFs become an animated UIImage (frames downsampled, preview only).
func loadPreview(_ url: URL) -> UIImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let n = CGImageSourceGetCount(src)
    guard n > 1 else { return AnimatedImage.image(src, 0, maxPixels: 1280).map(UIImage.init(cgImage:)) }
    let frames = (0..<n).compactMap { AnimatedImage.image(src, $0, maxPixels: 480).map(UIImage.init(cgImage:)) }
    return UIImage.animatedImage(with: frames, duration: AnimatedImage.delays(src).reduce(0, +))
}

/// SwiftUI's Image shows only the first frame of an animated UIImage; UIImageView plays it.
struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView(); v.contentMode = .scaleToFill   // frame already has the image's aspect
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }
    func updateUIView(_ v: UIImageView, context: Context) { if v.image !== image { v.image = image } }
}
