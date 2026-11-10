import AppKit
import SwiftUI

/// Progress while exporting, then a way to find the finished file.
struct ExportSheet: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.export {
            case .running(let progress):
                Text("Exporting MP4…").font(.headline)
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%  ·  1080p, hardware encoder")
                    .foregroundStyle(.secondary).font(.callout)
                HStack { Spacer(); Button("Cancel") { model.cancelExport() }.keyboardShortcut(.cancelAction) }
            case .finished(let url):
                Label("Export finished", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(.green)
                Text(url.lastPathComponent).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    Button("Done") { model.dismissExport() }.keyboardShortcut(.defaultAction)
                }
            case .failed(let message):
                Label("Export failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                Text(message).foregroundStyle(.secondary)
                HStack { Spacer(); Button("OK") { model.dismissExport() }.keyboardShortcut(.defaultAction) }
            case nil:
                EmptyView()
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
