import EditorCore
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

    // Corner radii.
    static let radiusSmall: CGFloat = 4      // thumbnails, stills, the preview's edge
    static let radius: CGFloat = 6           // buttons, swatches, tracks, bars
    static let radiusLarge: CGFloat = 12     // the empty window's drop area
    static let radiusSegmentGroup: CGFloat = 8   // the joined choice control's container
    static let radiusPanel: CGFloat = 8      // the floating side panel

    // Layout.
    static let panelWidth: CGFloat = 300
    static let panelPadding: CGFloat = 20    // same as the timeline's side margin
    static let sectionGap: CGFloat = 24      // between sections of a panel
    static let controlHeight: CGFloat = 28   // choice buttons, icon buttons
    static let iconButtonWidth: CGFloat = 32
    static let segmentHeight: CGFloat = 26   // one choice inside the joined choice control
    static let segmentPadding: CGFloat = 7   // space either side of a choice's word
    static let playButtonSize: CGFloat = 32
    static let toolIconGap: CGFloat = 6      // icon to word in a tool button
    static let toolTrailing: CGFloat = 10    // a tool button's right padding (8 on the left, by the icon)
    static let barLabelInset: CGFloat = 10   // clip and zoom labels from the bar's left edge

    // Colours.
    /// The accent blue. To go back to the system's accent colour, make this `Color.accentColor`.
    static let accent = Color(rgba: Settings.accentColor)
    /// Text links (the "‹ Style" back link): a lighter blue that reads well on the dark panel.
    static let link = Color(rgba: RGBAColor(hex: 0x6CB0FF))
    /// The floating side panel: only a touch lighter than the window, so it reads as a quiet card.
    static let panelFill = Color(rgba: RGBAColor(hex: 0x262628))
    /// The side panel's own thin scroll bar: width, gap from the panel's edges, colour.
    static let scrollThumbWidth: CGFloat = 6
    static let scrollThumbInset: CGFloat = 6
    static let scrollThumbMinHeight: CGFloat = 32
    static let scrollThumb = Color.white.opacity(0.16)
    static let playFill = Color(rgba: RGBAColor(hex: 0xF2F2F3))
    static let playGlyph = Color(rgba: RGBAColor(hex: 0x1C1C1E))
    static let controlFill = Color.white.opacity(0.08)
    static let controlHover = Color.white.opacity(0.14)
    static let hairline = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.62)   // a bit brighter than the system secondary, for dark panels
    static let tertiaryText = Color.white.opacity(0.45)
    static let clip = Color(rgba: Settings.timelineClipColor)
    static let clipSelected = Color(rgba: Settings.timelineSelectedClipColor)
    static let zoomSelected = Color(rgba: Settings.timelineSelectedZoomColor)
    static let clipLabel = Color(rgba: Settings.timelineClipLabelColor)
    static let editLine = Color(rgba: Settings.timelineEditLineColor)
    static let playhead = Color(rgba: Settings.timelinePlayheadColor)
    static let rulerText = Color.white.opacity(0.6)
    static let rulerTick = Color.white.opacity(0.28)
    static let rulerLine = Color.white.opacity(0.1)
    static let trackIcon = Color.white.opacity(0.5)
    static let zoom = Color(rgba: Settings.timelineZoomColor)
}

// MARK: - Panel pieces

/// The top of a side panel: an optional "‹ Style" back link, a title and a one-line detail.
struct PanelHeader: View {
    var back: (() -> Void)?
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            if let back {
                Button(action: back) {
                    Label("Style", systemImage: "chevron.left").font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.link)
                .help("Back to background and frame settings")
            }
            VStack(alignment: .leading, spacing: Theme.s1) {
                Text(title).font(.title3.weight(.semibold))
                if let detail {
                    Text(detail).font(.callout).foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A titled group of controls. `trailing` is an optional small control or value on the title's right.
struct PanelSection<Content: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack {
                Text(title).font(.headline)
                Spacer(minLength: Theme.s2)
                trailing
            }
            content
        }
    }
}

extension PanelSection where Trailing == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, trailing: { EmptyView() }, content: content)
    }
}

/// Small helper text under a control.
struct PanelNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.caption).foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The scrolling container every side panel uses: fixed width, same padding. It draws its own thin
/// scroll bar inside the panel's rounded edges (the system one would be cut off by the corners).
struct PanelScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
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
        .frame(width: Theme.panelWidth)
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
                .allowsHitTesting(false)
        }
    }
}

/// A label on the left, its value on the right, and a slider underneath.
struct SliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text(valueText).font(.callout.monospacedDigit()).foregroundStyle(Theme.secondaryText)
            }
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Buttons

/// One joined control holding a row of choices where one is selected (speed, easing, export size…).
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
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Theme.radiusSegmentGroup).fill(Theme.controlFill))
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
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, Theme.segmentPadding)
                .frame(maxWidth: .infinity, minHeight: Theme.segmentHeight, maxHeight: Theme.segmentHeight)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(selected ? Theme.accent : (hovering ? Theme.controlHover : Color.clear)))
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
        let width = proposal.width ?? ideal.reduce(0) { $0 + $1.width }
        return CGSize(width: width, height: ideal.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified).width }
        let sum = max(ideal.reduce(0, +), 1)
        var x = bounds.minX
        for (i, v) in subviews.enumerated() {
            let w = bounds.width * ideal[i] / sum
            v.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w
        }
    }
}

/// A tool button with an icon and a word (Cut, Crop, Zoom). Tools that stay on (Cut, Crop) light up while on.
struct ToolButton: View {
    let title: String
    let systemImage: String
    var isOn = false
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.toolIconGap) {
                Image(systemName: systemImage).font(.system(size: 14))
                Text(title).font(.body.weight(.medium))
            }
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(.leading, Theme.s2)
            .padding(.trailing, Theme.toolTrailing)
            .frame(height: Theme.controlHeight)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill(isOn ? Theme.accent : (hovering ? Theme.controlHover : Theme.controlFill)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// The screen's main button (Export in the top bar): accent fill, white text, the usual corner radius.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(height: Theme.controlHeight)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)))
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

/// Secondary button: a quiet filled pill for actions that aren't the screen's main one.
struct QuietButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(.horizontal, Theme.s3)
            .frame(minHeight: Theme.controlHeight)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill(configuration.isPressed || hovering ? Theme.controlHover : Theme.controlFill))
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
    }
}
