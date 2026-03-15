import Foundation

// MARK: - Alert Type Enum
enum ListRowAlert: Identifiable {
    case archive
    case permanentDelete
    case duplicate
    case shareError(String)

    var id: String {
        switch self {
        case .archive: return "archive"
        case .permanentDelete: return "permanentDelete"
        case .duplicate: return "duplicate"
        case .shareError: return "shareError"
        }
    }
}
