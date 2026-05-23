import CoreLocation
import Foundation

struct TripPlace: Decodable, Identifiable {
    var id: Int64
    var tripId: Int64
    var legId: Int64?
    var name: String
    var notes: String?
    var date: String?
    var lat: Double?
    var lng: Double?
    var googlePlaceId: String?
    var sortOrder: Int
    var isRouteAnchor: Bool
    var visitedAt: String?
    var rating: Int?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case legId = "leg_id"
        case name, notes, date, lat, lng
        case googlePlaceId = "google_place_id"
        case sortOrder = "sort_order"
        case isRouteAnchor = "is_route_anchor"
        case visitedAt = "visited_at"
        case rating
        case createdAt = "created_at"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
