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

    // Layout.
    static let panelWidth: CGFloat = 300
    static let panelPadding: CGFloat = 20    // same as the timeline's side margin
    static let sectionGap: CGFloat = 24      // between sections of a panel
    static let controlHeight: CGFloat = 28   // choice buttons, icon buttons
    static let iconButtonWidth: CGFloat = 32

    // Colours.
    static let accent = Color.accentColor
    static let controlFill = Color.white.opacity(0.08)
    static let controlHover = Color.white.opacity(0.14)
    static let hairline = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.62)   // a bit brighter than the system secondary, for dark panels
    static let tertiaryText = Color.white.opacity(0.45)
    static let clip = Color(rgba: Settings.timelineClipColor)
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
                .foregroundStyle(Theme.accent)
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

/// The scrolling container every side panel uses: fixed width, same padding and background.
struct PanelScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionGap) { content }
                .padding(Theme.panelPadding)
                .frame(width: Theme.panelWidth, alignment: .leading)
        }
        .frame(width: Theme.panelWidth)
        .background(.bar)
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

/// A row of equal-width choices where one is selected (speed, easing, export size…).
struct ChoiceButtons<Value: Hashable>: View {
    let choices: [Value]
    let isSelected: (Value) -> Bool
    let label: (Value) -> String
    let pick: (Value) -> Void

    var body: some View {
        HStack(spacing: Theme.s1) {
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
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Theme.controlHeight)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(selected ? Theme.accent : (hovering ? Theme.controlHover : Theme.controlFill)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A square icon button that lights up while "on" (scissors, crop) and shows a hover state.
struct ToolButton: View {
    let systemImage: String
    let isOn: Bool
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 16))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .frame(width: Theme.iconButtonWidth, height: Theme.controlHeight)
                .background(RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(isOn ? Theme.accent : (hovering ? Theme.controlHover : Color.clear)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
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
