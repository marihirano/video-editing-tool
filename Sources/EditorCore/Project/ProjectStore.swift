import Foundation

/// Saves and opens project packages: a folder named `Name.vetproj` holding `project.json`.
public enum ProjectStore {

    public enum StoreError: LocalizedError {
        case sourceMissing(String)
        public var errorDescription: String? {
            switch self {
            case .sourceMissing(let path):
                return "The original video couldn't be found. It was at:\n\(path)"
            }
        }
    }

    /// Writes the project into the package at `packageURL`, creating the folder if needed.
    /// Refreshes the source references (absolute path, relative path, bookmark) on the way.
    public static func save(_ project: Project, sourceURL: URL, to packageURL: URL) throws {
        var project = project
        project.source.path = sourceURL.path
        project.source.relativePath = relativePath(from: packageURL.deletingLastPathComponent(), to: sourceURL)
        project.source.bookmark = (try? sourceURL.bookmarkData())?.base64EncodedString()

        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(project)
        try data.write(to: packageURL.appendingPathComponent(Settings.projectFileName), options: .atomic)
    }

    /// Reads a project package and finds its source video.
    public static func load(from packageURL: URL) throws -> (project: Project, sourceURL: URL) {
        let data = try Data(contentsOf: packageURL.appendingPathComponent(Settings.projectFileName))
        let project = try JSONDecoder().decode(Project.self, from: data)
        guard let url = resolveSource(project.source, packageURL: packageURL) else {
            throw StoreError.sourceMissing(project.source.path)
        }
        return (project, url)
    }

    /// Tries the bookmark, then the path relative to the package, then the absolute path.
    static func resolveSource(_ source: SourceVideo, packageURL: URL) -> URL? {
        let fm = FileManager.default
        if let b64 = source.bookmark, let data = Data(base64Encoded: b64) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale),
               fm.fileExists(atPath: url.path) { return url }
        }
        if let rel = source.relativePath {
            let url = packageURL.deletingLastPathComponent().appendingPathComponent(rel).standardizedFileURL
            if fm.fileExists(atPath: url.path) { return url }
        }
        let url = URL(fileURLWithPath: source.path)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    static func relativePath(from base: URL, to target: URL) -> String {
        let b = base.standardizedFileURL.pathComponents
        let t = target.standardizedFileURL.pathComponents
        var i = 0
        while i < b.count, i < t.count, b[i] == t[i] { i += 1 }
        return (Array(repeating: "..", count: b.count - i) + t[i...]).joined(separator: "/")
    }
}
