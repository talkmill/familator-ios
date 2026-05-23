import Foundation

enum TransportMode: String, Codable, CaseIterable {
    case driving
    case walking
    case cycling

    var osrmProfile: String { rawValue }

    var displayName: String {
        switch self {
        case .driving: return "Drive"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        }
    }

    var systemImage: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }
}

enum TripTab: String, CaseIterable {
    case checklist
    case itinerary
    case places
    case legs
    case route
    case notes
    case attachments

    var label: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .checklist: return "checklist"
        case .itinerary: return "calendar"
        case .places: return "mappin.and.ellipse"
        case .legs: return "arrow.triangle.branch"
        case .route: return "map"
        case .notes: return "note.text"
        case .attachments: return "paperclip"
        }
    }
}

struct Trip: Codable, Identifiable {
    var id: Int64
    var listId: Int64
    var ownerId: UUID
    var workspaceId: String
    var destination: String
    var startDate: String?
    var endDate: String?
    var destinationLat: Double?
    var destinationLng: Double?
    var destinationPlaceId: String?
    var destinationPlaceName: String?
    var transportMode: TransportMode?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case ownerId = "owner_id"
        case workspaceId = "workspace_id"
        case destination
        case startDate = "start_date"
        case endDate = "end_date"
        case destinationLat = "destination_lat"
        case destinationLng = "destination_lng"
        case destinationPlaceId = "destination_place_id"
        case destinationPlaceName = "destination_place_name"
        case transportMode = "transport_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var status: TripStatus {
        let today = Self.isoDateFormatter.string(from: Date())
        return TripStatus.compute(startDate: startDate, endDate: endDate, today: today)
    }

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

enum TripStatus: String, CaseIterable, Identifiable {
    case inProgress = "in-progress"
    case upcoming
    case planning
    case past

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .upcoming: return "Upcoming"
        case .planning: return "Planning"
        case .past: return "Past"
        }
    }

    var sortOrder: Int {
        switch self {
        case .inProgress: return 0
        case .upcoming: return 1
        case .planning: return 2
        case .past: return 3
        }
    }

    /// Derives trip status from dates. Dates are ISO strings (YYYY-MM-DD).
    /// String comparison is correct for this format.
    static func compute(startDate: String?, endDate: String?, today: String) -> TripStatus {
        guard let startDate, let endDate else { return .planning }
        if endDate < today { return .past }
        if startDate <= today { return .inProgress }
        return .upcoming
    }
}
