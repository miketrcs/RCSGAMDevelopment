import Foundation

struct CSVRow: Sendable {
    let rowNumber: Int
    let account: String
    let rfc822MessageID: String
    let rawFields: [String: String]

    var validation: Validation {
        var missing: [String] = []
        if account.isEmpty {
            missing.append("Account")
        }
        if rfc822MessageID.isEmpty {
            missing.append("Rfc822MessageId")
        }
        return Validation(missingFields: missing)
    }
}

struct Validation: Sendable {
    let missingFields: [String]

    var isValid: Bool {
        missingFields.isEmpty
    }

    var reason: String {
        "missing \(missingFields.joined(separator: ", "))"
    }
}
