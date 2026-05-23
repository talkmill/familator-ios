import Foundation

enum ItineraryItemType: String, Codable, CaseIterable {
    case flight
    case hotel
    case tour
    case transport
    case activity
    case other

    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "bed.double"
        case .tour: return "binoculars"
        case .transport: return "bus"
        case .activity: return "figure.hiking"
        case .other: return "ellipsis.circle"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct TripItineraryItem: Decodable, Identifiable {
    var id: Int64
    var tripId: Int64
    var legId: Int64?
    var placeId: Int64?
    var workspaceId: String
    var ownerId: UUID
    var itemType: ItineraryItemType
    var title: String
    var description: String?
    var date: String?
    var startTime: String?
    var endTime: String?
    var confirmationNumber: String?
    var provider: String?
    var sortOrder: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case legId = "leg_id"
        case placeId = "place_id"
        case workspaceId = "workspace_id"
        case ownerId = "owner_id"
        case itemType = "item_type"
        case title
        case description
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case confirmationNumber = "confirmation_number"
        case provider
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension TripItineraryItem: Hashable {
    static func == (lhs: TripItineraryItem, rhs: TripItineraryItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
