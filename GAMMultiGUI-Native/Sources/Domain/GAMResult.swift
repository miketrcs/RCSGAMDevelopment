import Foundation

struct GAMResult: Sendable {
    enum Status: Sendable {
        case reviewValid
        case reviewSkip
        case preview
        case success
        case miss
        case dryRunSuccess
        case dryRunMiss
        case error
        case exception
    }

    let status: Status
    let user: String
    let detail: String
    let output: String
    let attempts: Int
    let rowNumber: Int?
}
