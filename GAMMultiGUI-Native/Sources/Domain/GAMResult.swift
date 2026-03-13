import Foundation

struct GAMResult: Sendable {
    enum Status: Sendable {
        case reviewValid
        case reviewSkip
        case preview
        case deleted
        case noMatch
        case dryRunFound
        case dryRunNoMatch
        case error
        case exception
    }

    let status: Status
    let user: String
    let messageID: String
    let output: String
    let attempts: Int
    let rowNumber: Int?
}
