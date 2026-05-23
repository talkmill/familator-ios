import Foundation

enum DashboardFavoriteItem {
    case list(listId: Int64, label: String)
    case filter(filterKey: String, label: String)
}

struct DashboardFavoriteRow: Codable {
    var userId: UUID
    var position: Int
    var itemType: String
    var listId: Int64?
    var filterKey: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case position
        case itemType = "item_type"
        case listId = "list_id"
        case filterKey = "filter_key"
    }

    static let typeList = "list"
    static let typeFilter = "filter"
}

enum DashboardFilterKey {
    static let all = ["due-now", "upcoming", "next-week", "all", "routines", "current"]
    static let labels: [String: String] = [
        "due-now": "Due Now",
        "upcoming": "Upcoming",
        "next-week": "Next week",
        "all": "All tasks",
        "routines": "Recurring",
        "current": "Current",
    ]
}
