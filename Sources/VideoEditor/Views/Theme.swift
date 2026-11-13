import CoreText
import EditorCore
import Foundation
import SwiftUI

/// Every spacing, size, radius and colour the interface shares, in one place, plus the few
/// small building blocks (panel header, section, slider row, choice buttons) that all four
/// side panels and the export window use so they look the same.
enum Theme {
    // Spacing scale: use only these.
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24

    // Type: every piece of text is Inter at regular weight, with no bold or medium anywhere (Mari, 2026-11-13).
    // The font file is Resources/Fonts/Inter.woff2; if it's missing, text falls back to the system font.
    static let fontName = "Inter"
    static func font(_ size: CGFloat) -> Font { .custom(fontName, fixedSize: size) }
    static let fontLarge = font(17)      // the empty window's headline
    static let fontTitle = font(15)      // panel and export-window titles
    static let fontBody = font(13)       // the default: buttons, section titles, bar labels
    static let fontCallout = font(12)    // slider rows, choices, details
    static let fontSmall = font(11)      // ruler times
    static let fontCaption = font(10)    // notes

    /// Loads Inter from the app's Resources/Fonts folder. Call once, before any window appears.
    static func registerFonts() {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Fonts/Inter.woff2"),
              FileManager.default.fileExists(atPath: url.path) else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    // Corner radii.
    static let radiusSmall: CGFloat = 4      // thumbnails, stills, the preview's edge
    static let radius: CGFloat = 6           // buttons, swatches, tracks, bars
    static let radiusLarge: CGFloat = 12     // the empty window's drop area
    static let radiusPanel: CGFloat = 8      // the floating side panel

    // Layout.
    static let panelWidth: CGFloat = 306
    static let panelPadding: CGFloat = 20    // inside the side panel
    static let windowMargin: CGFloat = 24    // left and right of the preview and panel
    static let panelGap: CGFloat = 32        // between the preview and the side panel
    static let timelineMargin: CGFloat = 24   // left and right of the timeline
    static let transportHeight: CGFloat = 64 // the tools / play / time row under the preview
    static let cropRowHeight: CGFloat = 48   // the Crop button centred above the preview
    static let transportMinWidth: CGFloat = 420 // the tools / play / time row never gets narrower (9:16 previews are narrow)
    static let sectionGap: CGFloat = 32      // between sections of a panel
    static let controlHeight: CGFloat = 32   // choice buttons, icon buttons
    static let iconButtonWidth: CGFloat = 32
    static let playButtonSize: CGFloat = 32
    static let barLabelInset: CGFloat = 16   // clip and zoom labels from the bar's left edge

    // MARK: Colours
    // Each colour that differs between dark and light is built with `adaptive(dark:light:)` and follows the window's
    // appearance, which `AppearanceMode` sets (System / Light / Dark). The light values are Claude's proposal (2026-11-13).
    // Body text is at least 4.5:1 on its background in both modes; see the table in CLAUDE.md.

    /// The appearance choice: follows the Mac, or forced light or dark. Saved under `appearanceKey`.
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String { switch self { case .system: "System"; case .light: "Light"; case .dark: "Dark" } }
        /// nil = follow the Mac's appearance, and keep following it as it changes.
        var nsAppearance: NSAppearance? {
            switch self { case .system: nil; case .light: NSAppearance(named: .aqua); case .dark: NSAppearance(named: .darkAqua) }
        }
        @MainActor static func apply(_ raw: String) { NSApp.appearance = (AppearanceMode(rawValue: raw) ?? .system).nsAppearance }
    }
    static let appearanceKey = "appearance"

    static func adaptive(dark: RGBAColor, light: RGBAColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
        })
    }
    /// Text or lines drawn with the window's text colour at a different strength in each mode (white in dark, black in light).
    private static func ink(dark: Double, light: Double) -> Color {
        adaptive(dark: RGBAColor(r: 1, g: 1, b: 1, a: dark), light: RGBAColor(r: 0, g: 0, b: 0, a: light))
    }
    private static func withAlpha(_ c: RGBAColor, _ a: Double) -> RGBAColor { RGBAColor(r: c.r, g: c.g, b: c.b, a: a) }

    // Window and panel.
    /// The window behind everything (and the top bar).
    static let windowBackground = adaptive(dark: Settings.previewSurround, light: RGBAColor(hex: 0xF2F2F4))
    /// The floating side panel: a quiet card, a touch lighter than the window in dark and white in light.
    static let panelFill = adaptive(dark: RGBAColor(hex: 0x262628), light: RGBAColor(hex: 0xFFFFFF))
    /// The accent teal. Light mode uses a deeper teal so white text on it, and the teal as text, pass 4.5:1.
    static let accent = adaptive(dark: Settings.accentColor, light: RGBAColor(hex: 0x007683))
    /// Text links (the "← Style" back link).
    static let link = adaptive(dark: RGBAColor(hex: 0x6CB0FF), light: RGBAColor(hex: 0x007683))

    // Text and lines.
    static let secondaryText = ink(dark: 0.62, light: 0.65)
    static let tertiaryText = ink(dark: 0.45, light: 0.58)
    static let hairline = Color.primary.opacity(0.12)
    static let controlFill = Color.primary.opacity(0.08)
    static let controlHover = Color.primary.opacity(0.14)
    static let playFill = adaptive(dark: RGBAColor(hex: 0xF2F2F3), light: RGBAColor(hex: 0x1D1D1F))

    // Side-panel scroll bar and slider.
    static let scrollThumbWidth: CGFloat = 6
    static let scrollThumbInset: CGFloat = 6
    static let scrollThumbMinHeight: CGFloat = 32
    static let scrollThumb = Color.primary.opacity(0.16)
    /// The slider's empty track (a little stronger in light, where 8% black on white is hard to see).
    static let sliderTrack = ink(dark: 0.08, light: 0.14)
    /// The slider knob.
    static let sliderThumb = adaptive(dark: RGBAColor(hex: 0x96BABE), light: RGBAColor(hex: 0x5B9AA2))

    // Timeline.
    /// Bar labels and grips: white in both modes.
    static let clipLabel = Color(rgba: Settings.timelineClipLabelColor)
    /// Bar fills: see-through in dark; nearly solid in light so the white labels stay readable (Mari preferred this, 2026-11-13).
    static let clipBar = adaptive(dark: withAlpha(Settings.timelineClipColor, Settings.timelineClipOpacity), light: withAlpha(RGBAColor(hex: 0xC81F68), 0.92))
    static let clipBarSelected = adaptive(dark: withAlpha(Settings.timelineSelectedClipColor, Settings.timelineClipOpacity), light: withAlpha(RGBAColor(hex: 0x9E1650), 0.95))
    /// The ring around the selected clip / zoom.
    static let clipSelected = adaptive(dark: Settings.timelineSelectedClipColor, light: RGBAColor(hex: 0xFFFFFF))
    static let zoomSelected = adaptive(dark: Settings.timelineSelectedZoomColor, light: RGBAColor(hex: 0xFFFFFF))
    static let zoomBar = adaptive(dark: withAlpha(Settings.timelineZoomColor, Settings.timelineBarOpacity), light: withAlpha(Settings.timelineZoomColor, 0.92))
    static let zoomPlus = adaptive(dark: RGBAColor(r: 1, g: 1, b: 1, a: 0.9), light: Settings.timelineZoomColor)
    static let zoom = adaptive(dark: Settings.timelineZoomColor, light: RGBAColor(hex: 0x007683))
    static let zoomTrack = adaptive(dark: Settings.timelineZoomTrackColor, light: RGBAColor(hex: 0xE3EFF1))
    /// The soft shadow along the top of clip and zoom bars.
    static let barInnerShadow = adaptive(dark: RGBAColor(r: 0, g: 0, b: 0, a: 0.25), light: RGBAColor(r: 0, g: 0, b: 0, a: 0.18))
    /// The playhead's line and handle.
    static let playhead = accent
    static let editLine = adaptive(dark: Settings.timelineEditLineColor, light: RGBAColor(r: 0, g: 0, b: 0, a: 0.3))
    static let editTag = adaptive(dark: Settings.timelineEditTagColor, light: RGBAColor(hex: 0xE4E4E7))
    static let rulerText = tertiaryText
    static let rulerTick = ink(dark: 0.28, light: 0.5)
    static let rulerLine = Color.primary.opacity(0.1)
    static let trackIcon = Color.primary.opacity(0.5)
}

// MARK: - Panel pieces

/// The top of a side panel. With a back link ("← Style") the link is all there is: the panel's own
/// contents say what is selected. Without one (the Style panel) it shows the title.
/// `alwaysShowTitle` keeps the title and an optional detail line next to a back link (the Crop panel).
struct PanelHeader: View {
    var back: (() -> Void)?
    let title: String
    var detail: String?
    var alwaysShowTitle = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            if let back {
                Button(action: back) {
                    HStack(spacing: Theme.s1) {
                        Image(systemName: "arrow.left").font(.system(size: 12, weight: .light))
                        Text("Style").font(Theme.fontCallout)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
                .help("Back to background and frame settings")
            }
            if back == nil || alwaysShowTitle {
                VStack(alignment: .leading, spacing: Theme.s1) {
                    Text(title).font(Theme.fontTitle)
                    if let detail {
                        Text(detail).font(Theme.fontCallout).foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// A titled group of controls. `trailing` is an optional small control or value on the title's right.
struct PanelSection<Content: View, Trailing: View>: View {
    let title: String
    /// Space between the title and the controls (and between the controls): 16, or 18 in the zoom panel.
    var spacing: CGFloat = Theme.s4
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack {
                Text(title).font(Theme.fontBody)
                Spacer(minLength: Theme.s2)
                trailing
            }
            content
        }
    }
}

extension PanelSection where Trailing == EmptyView {
    init(_ title: String, spacing: CGFloat = Theme.s4, @ViewBuilder content: () -> Content) {
        self.init(title: title, spacing: spacing, trailing: { EmptyView() }, content: content)
    }
}

/// Small helper text under a control.
struct PanelNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.fontCaption).foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The scrolling container every side panel uses: fixed width, same padding. It draws its own thin
/// scroll bar inside the panel's rounded edges (the system one would be cut off by the corners).
struct PanelScaffold<Content: View, Footer: View>: View {
    let content: Content
    /// Pinned to the bottom of the panel, outside the scrolling part (the Delete clip button).
    let footer: Footer
    @State private var contentHeight: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            scrolling
            footer
                .padding([.horizontal, .bottom], Theme.panelPadding)
                .frame(width: Theme.panelWidth, alignment: .leading)
        }
        .frame(width: Theme.panelWidth)
        .onHover { hovering = $0 }
    }

    private var scrolling: some View {
        GeometryReader { outer in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionGap) { content }
                    .padding(Theme.panelPadding)
                    .frame(width: Theme.panelWidth, alignment: .leading)
                    .background(GeometryReader { g in
                        Color.clear
                            .onAppear { measure(g) }
                            .onChange(of: g.frame(in: .named("panelScroll"))) { measure(g) }
                    })
            }
            .coordinateSpace(name: "panelScroll")
            .scrollIndicators(.never)
            .overlay(alignment: .topTrailing) { thumb(visible: outer.size.height) }
        }
    }

    private func measure(_ g: GeometryProxy) {
        let f = g.frame(in: .named("panelScroll"))
        contentHeight = f.height
        offset = -f.minY
    }

    /// A rounded bar showing how much of the panel is in view and where; only when there's more to scroll to.
    @ViewBuilder private func thumb(visible h: CGFloat) -> some View {
        if contentHeight > h + 1 {
            let track = h - Theme.scrollThumbInset * 2
            let size = max(track * h / contentHeight, Theme.scrollThumbMinHeight)
            let progress = min(max(offset / (contentHeight - h), 0), 1)
            Capsule().fill(Theme.scrollThumb)
                .frame(width: Theme.scrollThumbWidth, height: size)
                .offset(x: -Theme.scrollThumbInset, y: Theme.scrollThumbInset + progress * (track - size))
                .opacity(hovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: hovering)
                .allowsHitTesting(false)
        }
    }
}

extension PanelScaffold {
    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.footer = footer()
    }
}

extension PanelScaffold where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, footer: { EmptyView() })
    }
}

/// A label on the left, its value on the right, and a slider underneath.
struct SliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        // 4 pt between the label and the slider's 16 pt frame puts the 4 pt track 12 pt below the label.
        VStack(alignment: .leading, spacing: Theme.s1) {
            HStack {
                Text(title).font(Theme.fontCallout).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(valueText).font(Theme.fontCallout.monospacedDigit()).foregroundStyle(Theme.tertiaryText)
            }
            ThemedSlider(value: $value, range: range)
        }
    }
}

/// A small number box with its unit inside ("1 ×").
struct NumberField: View {
    @Binding var text: String
    var suffix: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: Theme.s1) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .focused(focused)
                .onSubmit(onSubmit)
            Text(suffix).foregroundStyle(Theme.secondaryText)
        }
        .font(Theme.fontCallout)
        .padding(.horizontal, Theme.s2)
        .frame(width: 60, height: 33)
        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.windowBackground))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.hairline))
    }
}

/// The slider every panel uses: a 4 pt track, the filled part in the accent colour, and a 16 pt round knob.
struct ThemedSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    private let knob: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let span = max(range.upperBound - range.lowerBound, 0.000001)
            let fraction = min(max((value - range.lowerBound) / span, 0), 1)
            let travel = max(geo.size.width - knob, 1)
            let x = CGFloat(fraction) * travel
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.sliderTrack).frame(height: 4)
                Capsule().fill(Theme.accent).frame(width: x + knob / 2, height: 4)
                Circle().fill(Theme.sliderThumb).frame(width: knob, height: knob).offset(x: x)
            }
            .frame(height: knob)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(max(Double((g.location.x - knob / 2) / travel), 0), 1)
                value = range.lowerBound + f * span
            })
        }
        .frame(height: knob)
    }
}

// MARK: - Buttons

/// A row of choices where one is selected (speed, easing, export size…): flat words, the chosen one on a grey pill.
/// Each choice gets room in proportion to its word, so long words never touch their edges.
struct ChoiceButtons<Value: Hashable>: View {
    let choices: [Value]
    let isSelected: (Value) -> Bool
    let label: (Value) -> String
    let pick: (Value) -> Void

    var body: some View {
        ProportionalRow {
            ForEach(choices, id: \.self) { c in
                ChoiceButton(label: label(c), selected: isSelected(c)) { pick(c) }
            }
        }
    }
}

struct ChoiceButton: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.fontCallout)
                .lineLimit(1)
                .fixedSize()   // the word never shrinks; in a tight row the padding gives way instead
                .padding(.horizontal, Theme.s3)
                .padding(.vertical, Theme.s2)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.primary)
                .background(RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(selected ? Theme.controlFill : (hovering ? Theme.controlFill.opacity(0.6) : Color.clear)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Lays children out in one row, filling the width; each child's share is in proportion to its natural width.
private struct ProportionalRow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let gaps = Theme.s1 * CGFloat(max(subviews.count - 1, 0))
        let width = proposal.width ?? (ideal.reduce(0) { $0 + $1.width } + gaps)
        return CGSize(width: width, height: ideal.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified).width }
        let sum = max(ideal.reduce(0, +), 1)
        let gaps = Theme.s1 * CGFloat(max(subviews.count - 1, 0))
        let spare = bounds.width - gaps - sum   // negative: too tight, so every choice gives up the same amount of padding
        var x = bounds.minX
        for (i, v) in subviews.enumerated() {
            let w = spare >= 0 ? (bounds.width - gaps) * ideal[i] / sum : ideal[i] + spare / CGFloat(max(subviews.count, 1))
            v.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w + Theme.s1
        }
    }
}

/// A tool button with just an icon (Cut, Crop, Zoom); `title` is its accessibility name. No box until
/// you point at it; tools that stay on (Cut, Crop) light up while on.
struct ToolButton: View {
    let title: String
    let systemImage: String
    var isOn = false
    var showsTitle = false
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s2) {
                Image(systemName: systemImage).font(.system(size: 14, weight: .light))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                if showsTitle {
                    Text(title).font(Theme.fontBody)
                        .foregroundStyle(isOn ? Color.white : Theme.secondaryText)
                }
            }
                .padding(.horizontal, showsTitle ? Theme.s3 : 8)
                .frame(minWidth: 30, minHeight: 28)
                .background(RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(isOn ? Theme.accent : (hovering ? Theme.controlHover : Color.clear)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(title)
    }
}

/// The screen's main button (Export in the top bar): accent fill, white text, the usual corner radius.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.fontBody)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Theme.s3)
            .padding(.vertical, Theme.s2)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)))
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

/// Secondary button: a quiet filled pill for actions that aren't the screen's main one.
struct QuietButtonStyle: ButtonStyle {
    var destructive = false
    /// Stretch across the whole panel (Delete clip).
    var fullWidth = false
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.fontCallout)
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(.horizontal, Theme.s3)
            .padding(.vertical, Theme.s2)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill(configuration.isPressed || hovering ? Theme.controlHover : Theme.controlFill))
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
    }
}

// MARK: - Inner shadow

/// A shadow inside a rounded shape along its top edge, like Figma's "inner shadow" with an offset down
/// (`y`) and a blur (`blur` is Figma's number): a soft fade from the top edge. Drawn as a gradient so it
/// looks the same everywhere (no blur filter).
struct InnerShadow: ViewModifier {
    let radius: CGFloat
    let color: Color
    let y: CGFloat
    let blur: CGFloat

    /// How dark the shadow is at `depth` points below the top edge: the shape, moved down by `y`, is cut out
    /// of a dark sheet and the edge is softened with a bell curve of spread blur / 2.
    private func strength(at depth: CGFloat) -> Double {
        let sigma = Double(max(blur, 0.1)) / 2
        let z = (Double(depth) - Double(y)) / sigma
        return 1 - 0.5 * (1 + erf(z / 2.0.squareRoot()))
    }

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { g in
                let h = max(g.size.height, 1)
                let reach = y + blur * 1.5
                let steps = 14
                let stops = (0...steps).map { i -> Gradient.Stop in
                    let d = reach * CGFloat(i) / CGFloat(steps)
                    return .init(color: color.opacity(strength(at: d)), location: min(d / h, 1))
                }
                LinearGradient(stops: stops + [.init(color: color.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func innerShadow(radius: CGFloat, color: Color, y: CGFloat, blur: CGFloat) -> some View {
        modifier(InnerShadow(radius: radius, color: color, y: y, blur: blur))
    }
}
