import AppKit
import EditorCore
import SwiftUI

/// The export window: pick format, size and frame rate (with a size estimate), then progress,
/// then a way to find the finished file.
struct ExportSheet: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.export {
            case .choosing:
                ExportOptions()
            case .running(let progress):
                Text("Exporting…").font(.headline)
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%  ·  \(model.exportSummary)")
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

private struct ExportOptions: View {
    @EnvironmentObject private var model: EditorModel
    @State private var gifEstimate: GIFEstimate?
    @State private var estimating = false

    private var output: OutputSettings { model.project?.output ?? OutputSettings() }
    private var isGIF: Bool { output.format == .gif }

    var body: some View {
        Text("Export").font(.headline)
        Picker("Format", selection: Binding(get: { output.format }, set: { f in model.setOutput { $0.format = f } })) {
            Text("MP4 video").tag(OutputSettings.Format.mp4)
            Text("GIF").tag(OutputSettings.Format.gif)
        }
        .pickerStyle(.segmented).labelsHidden()

        if isGIF {
            row("Size", Settings.gifHeights, selected: output.gifHeight, label: { "\($0)p" }) { h in model.setOutput { $0.gifHeight = h } }
            row("Frame rate", Settings.gifFPSChoices, selected: output.gifFPS, label: { "\($0)" }) { f in model.setOutput { $0.gifFPS = f } }
        } else {
            row("Size", Settings.mp4Heights, selected: output.height, label: { $0 == 2160 ? "4K" : "\($0)p" }) { h in model.setOutput { $0.setMP4Height(h) } }
            row("Frame rate", Settings.mp4FPSChoices, selected: output.fps, label: { "\($0)" }) { f in model.setOutput { $0.fps = f } }
        }

        VStack(alignment: .leading, spacing: 2) {
            Text(model.exportSummary).font(.callout)
            Text(sizeText).font(.callout).foregroundStyle(.secondary)
            if isGIF { Text("GIFs get big quickly. For long clips, a smaller size or lower frame rate helps.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 2) }
        }
        .task(id: EstimateKey(project: model.project, isGIF: isGIF)) { await estimate() }

        HStack {
            Spacer()
            Button("Cancel") { model.dismissExport() }.keyboardShortcut(.cancelAction)
            Button("Export…") { model.confirmExport() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
        }
    }

    private struct EstimateKey: Equatable { var project: Project?; var isGIF: Bool }

    private func row(_ title: String, _ values: [Int], selected: Int, label: @escaping (Int) -> String, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            Picker(title, selection: Binding(get: { selected }, set: set)) {
                ForEach(values, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
        }
    }

    private var duration: Double { model.timeMap?.outputDuration ?? 0 }

    private var sizeText: String {
        if isGIF {
            if let e = gifEstimate { return "\(e.frames) frames · about \(Self.megabytes(e.bytes))" }
            return estimating ? "Estimating size…" : ""
        }
        let megapixels = Double(output.width * output.height) / 1_000_000
        return "\(String(format: "%.0f", duration)) s · about \(Self.megabytes(Int(megapixels * Settings.exportBitsPerMegapixel * duration / 8)))"
    }

    private static func megabytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_000_000
        return mb < 10 ? String(format: "%.1f MB", mb) : String(format: "%.0f MB", mb)
    }

    private func estimate() async {
        gifEstimate = nil
        guard isGIF, let project = model.project, let url = model.sourceURL else { return }
        estimating = true
        try? await Task.sleep(nanoseconds: 250_000_000)   // wait while a choice is still being changed
        if Task.isCancelled { return }
        gifEstimate = try? await Exporter().estimateGIF(project: project, sourceURL: url)
        estimating = false
    }
}
