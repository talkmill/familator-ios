import Foundation

struct TripLeg: Decodable, Identifiable {
    var id: Int64
    var tripId: Int64
    var name: String
    var sortOrder: Int
    var transportMode: TransportMode
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case name
        case sortOrder = "sort_order"
        case transportMode = "transport_mode"
        case createdAt = "created_at"
    }
}

extension TripLeg: Hashable {
    static func == (lhs: TripLeg, rhs: TripLeg) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
