import Foundation

struct CSVRow: Sendable {
    let rowNumber: Int
    let user: String
    let detail: String
    let rawFields: [String: String]
    let missingFields: [String]

    var validation: Validation {
        Validation(missingFields: missingFields)
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
