import Foundation

/// Converts between output time (the finished video) and source time (the recording).
///
/// Preview and export both ask this one place, so trims, cuts and speed-ups (M3)
/// only need to be taught here. In M1 the two clocks are the same.
public struct TimeMap: Sendable {
    public let sourceDuration: Double
    public let timeline: Timeline

    public init(project: Project, sourceDuration: Double) {
        self.sourceDuration = sourceDuration
        self.timeline = project.timeline
    }

    /// Length of the finished video, in seconds.
    public var outputDuration: Double { sourceDuration }

    /// Source moment shown at a given output moment. Never goes backwards as output time
    /// moves forwards, which lets export read the source in one pass.
    public func sourceTime(forOutput t: Double) -> Double {
        min(max(t, 0), sourceDuration)
    }
}
