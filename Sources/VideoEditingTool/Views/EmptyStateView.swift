import AppKit
import SwiftUI

/// Shown when nothing is open: the app icon, an invitation to drop a file, and the basics.
struct EmptyStateView: View {
    @EnvironmentObject private var model: EditorModel
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
                .scaleEffect(isTargeted ? 1.08 : 1)
            Text(isTargeted ? "Drop to open" : "Drop a screen recording here")
                .font(.title2.weight(.medium))
            Text("MOV or MP4, or a saved project")
                .foregroundStyle(.secondary)
            Button("Choose a File…") { Task { await model.showOpenPanel() } }
                .controlSize(.large)
                .padding(.top, 6)
            Text("Then: cut with the scissors (⌘T), add zooms on the zoom track, style the frame on the right, and Export (⌘E).")
                .font(.callout).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 18)
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
