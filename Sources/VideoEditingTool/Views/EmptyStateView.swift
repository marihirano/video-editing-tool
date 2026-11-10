import SwiftUI

/// Shown when nothing is open: invites a drop or File › Open.
struct EmptyStateView: View {
    @EnvironmentObject private var model: EditorModel
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "film.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("Drop a screen recording here")
                .font(.title2.weight(.medium))
            Text("MOV or MP4 · or a saved project")
                .foregroundStyle(.secondary)
            Button("Choose a File…") { Task { await model.showOpenPanel() } }
                .controlSize(.large)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(isTargeted ? 0.08 : 0)))
                .padding(28)
        )
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}
