import Foundation

enum AppError: LocalizedError {
    case notImplemented(String)
    case csvFileNotFound(String)
    case invalidCSV(String)
    case unsupportedMode(String)
    case gamNotFound
    case processLaunchFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notImplemented(let symbol):
            return "\(symbol) is not implemented yet."
        case .csvFileNotFound(let path):
            return "CSV file not found: \(path)"
        case .invalidCSV(let message):
            return "Invalid CSV: \(message)"
        case .unsupportedMode(let mode):
            return "Mode \(mode) is not implemented yet."
        case .gamNotFound:
            return "GAM was not found on this Mac."
        case .processLaunchFailed(let message):
            return "Failed to launch process: \(message)"
        case .cancelled:
            return "Operation cancelled."
        }
    }
}
