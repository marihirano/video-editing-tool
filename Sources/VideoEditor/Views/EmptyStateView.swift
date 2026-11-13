import AppKit
import SwiftUI

/// Shown when nothing is open: the app icon, an invitation to drop a file, and the basics.
struct EmptyStateView: View {
    @EnvironmentObject private var model: EditorModel
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: Theme.s3) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
                .scaleEffect(isTargeted ? 1.08 : 1)
            Text(isTargeted ? "Drop to open" : "Drop a screen recording here")
                .font(.title2.weight(.medium))
            Text("MOV or MP4, or a saved project")
                .foregroundStyle(Theme.secondaryText)
            Button("Choose a File…") { Task { await model.showOpenPanel() } }
                .controlSize(.large)
                .padding(.top, Theme.s2)
            Text("Then: cut with the scissors (⌘T), add zooms on the zoom track, style the frame on the right, and Export (⌘E).")
                .font(.callout).foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, Theme.s4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .strokeBorder(isTargeted ? Theme.accent : Theme.hairline,
                              style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .background(RoundedRectangle(cornerRadius: Theme.radiusLarge).fill(Theme.accent.opacity(isTargeted ? 0.08 : 0)))
                .padding(Theme.s5)
        )
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}
