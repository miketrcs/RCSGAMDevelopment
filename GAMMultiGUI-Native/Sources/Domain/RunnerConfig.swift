import Foundation

struct RunnerConfig: Sendable {
    let csvPath: String
    let gamPathOverride: String
    let mode: RunnerMode
    let workers: Int
    let retries: Int
    let backoffSeconds: Double
}
