import Foundation

enum BulkAction: String, CaseIterable, Identifiable, Sendable {
    case deleteVaultMessages
    case suspendUsersCSV
    case archiveUsersCSV
    case changePasswordsCSV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deleteVaultMessages:
            return "Delete Vault Messages"
        case .suspendUsersCSV:
            return "Suspend Users from CSV"
        case .archiveUsersCSV:
            return "Archive Users from CSV"
        case .changePasswordsCSV:
            return "Change Passwords from CSV"
        }
    }

    var subtitle: String {
        switch self {
        case .deleteVaultMessages:
            return "Delete messages from Vault metadata CSV rows that include Account and Rfc822MessageId."
        case .suspendUsersCSV:
            return "Suspend users listed in a CSV that contains an email or account column."
        case .archiveUsersCSV:
            return "Archive users listed in a CSV that contains an email or account column."
        case .changePasswordsCSV:
            return "Change passwords for users listed in a CSV that contains a user column and password column."
        }
    }

    var csvPrompt: String {
        switch self {
        case .deleteVaultMessages:
            return "Path to Vault metadata CSV"
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return "Path to user CSV"
        }
    }

    var csvHelpTitle: String {
        switch self {
        case .deleteVaultMessages:
            return "Vault Delete CSV"
        case .suspendUsersCSV:
            return "Suspend Users CSV"
        case .archiveUsersCSV:
            return "Archive Users CSV"
        case .changePasswordsCSV:
            return "Change Passwords CSV"
        }
    }

    var executeButtonTitle: String {
        switch self {
        case .deleteVaultMessages:
            return "Execute Deletes (DOIT)"
        case .suspendUsersCSV:
            return "Execute Suspends"
        case .archiveUsersCSV:
            return "Execute Archives"
        case .changePasswordsCSV:
            return "Execute Password Changes"
        }
    }

    var successSummaryLabel: String {
        switch self {
        case .deleteVaultMessages:
            return "deleted"
        case .suspendUsersCSV, .archiveUsersCSV:
            return "updated"
        case .changePasswordsCSV:
            return "passwords_changed"
        }
    }
}
