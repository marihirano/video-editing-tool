import EditorCore
import SwiftUI

/// The panel on the right: background, padding, corners and shadow. Every change shows in the preview at once.
struct InspectorView: View {
    @EnvironmentObject private var model: EditorModel

    private var style: FrameStyle { model.project?.style ?? FrameStyle() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Background") { backgroundControls }
                section("Frame") {
                    slider("Padding", value: \.padding, range: Settings.paddingRange, unit: "%")
                    slider("Corners", value: \.cornerRadius, range: Settings.cornerRadiusRange, unit: "")
                }
                section("Shadow") {
                    slider("Opacity", value: \.shadowOpacity, range: Settings.shadowOpacityRange, unit: "", scale: 100, suffix: "%")
                    slider("Blur", value: \.shadowBlur, range: Settings.shadowBlurRange, unit: "")
                    slider("Distance", value: \.shadowOffset, range: Settings.shadowOffsetRange, unit: "")
                }
                Button("Reset style") { model.updateStyle { $0 = FrameStyle() } }
                    .controlSize(.small)
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
        .frame(width: 300)
        .background(.bar)
    }

    // MARK: Background

    @ViewBuilder private var backgroundControls: some View {
        Picker("", selection: Binding(get: { style.kind }, set: { k in model.updateStyle { $0.kind = k } })) {
            Text("Wallpaper").tag(BackgroundKind.wallpaper)
            Text("Gradient").tag(BackgroundKind.gradient)
            Text("Color").tag(BackgroundKind.solid)
            Text("Image").tag(BackgroundKind.image)
        }
        .labelsHidden()
        .pickerStyle(.segmented)

        switch style.kind {
        case .wallpaper:
            swatchGrid {
                ForEach(Array(Settings.wallpapers.enumerated()), id: \.offset) { i, w in
                    swatch(selected: style.wallpaper == i, name: w.name,
                           fill: AnyShapeStyle(LinearGradient(colors: [w.colors[0], w.colors[1], w.colors[3], w.colors[2]].map { Color(rgba: $0) },
                                                              startPoint: .topLeading, endPoint: .bottomTrailing))) {
                        model.updateStyle { $0.wallpaper = i }
                    }
                }
            }
        case .gradient:
            swatchGrid {
                ForEach(Array(Settings.gradients.enumerated()), id: \.offset) { _, g in
                    swatch(selected: style.gradientStart == g.start && style.gradientEnd == g.end, name: g.name,
                           fill: AnyShapeStyle(LinearGradient(colors: [Color(rgba: g.start), Color(rgba: g.end)],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing))) {
                        model.updateStyle { $0.gradientStart = g.start; $0.gradientEnd = g.end; $0.gradientAngle = g.angle }
                    }
                }
            }
            HStack {
                ColorPicker("From", selection: colorBinding(\.gradientStart))
                ColorPicker("To", selection: colorBinding(\.gradientEnd))
            }
            slider("Angle", value: \.gradientAngle, range: 0...360, unit: "°")
        case .solid:
            ColorPicker("Color", selection: colorBinding(\.background))
        case .image:
            Button(style.imagePath == nil ? "Choose picture…" : "Change picture…") {
                if let url = FilePanels.chooseBackgroundImage() {
                    model.updateStyle { $0.imagePath = url.path }
                }
            }
            if let path = style.imagePath {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
        }
    }

    private func swatchGrid<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8, content: content)
    }

    private func swatch(selected: Bool, name: String, fill: AnyShapeStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(fill)
                .frame(height: 38)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Color.accentColor : .white.opacity(0.12), lineWidth: selected ? 2.5 : 1))
        }
        .buttonStyle(.plain)
        .help(name)
    }

    // MARK: Helpers

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func slider(_ title: String, value: WritableKeyPath<FrameStyle, Double>, range: ClosedRange<Double>,
                        unit: String, scale: Double = 1, suffix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((style[keyPath: value] * scale).rounded()))\(suffix ?? unit)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            .font(.callout)
            Slider(value: Binding(get: { style[keyPath: value] }, set: { v in model.updateStyle { $0[keyPath: value] = v } }), in: range)
                .controlSize(.small)
        }
    }

    private func colorBinding(_ path: WritableKeyPath<FrameStyle, RGBAColor>) -> Binding<Color> {
        Binding(get: { Color(rgba: style[keyPath: path]) }, set: { new in
            let c = NSColor(new).usingColorSpace(.sRGB) ?? .black
            model.updateStyle { $0[keyPath: path] = RGBAColor(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: 1) }
        })
    }
}
