import Foundation

enum RunnerMode: String, CaseIterable, Identifiable {
    case review
    case preview
    case check
    case execute

    var id: String { rawValue }

    func title(for action: BulkAction) -> String {
        switch self {
        case .review:
            return "Review CSV"
        case .preview:
            return "Preview Commands"
        case .check:
            return "Check (first 10)"
        case .execute:
            return action.executeButtonTitle
        }
    }
}
