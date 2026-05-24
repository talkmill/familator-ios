import Foundation
import Supabase

struct TripPlaceInsert: Encodable {
    let tripId: Int64
    let name: String
    let lat: Double?
    let lng: Double?
    let googlePlaceId: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case name, lat, lng
        case googlePlaceId = "google_place_id"
        case sortOrder = "sort_order"
    }
}

struct TripPlaceUpdate: Encodable {
    var name: String?
    var notes: String?
    var date: String?
    var lat: Double?
    var lng: Double?
    var googlePlaceId: String?
    var sortOrder: Int?
    var rating: Int?
    var visitedAt: String?
    var legId: Int64?
    var isRouteAnchor: Bool?
    var clearDate: Bool = false
    var clearRating: Bool = false
    var clearVisitedAt: Bool = false
    var clearLegId: Bool = false
    var clearNotes: Bool = false

    enum CodingKeys: String, CodingKey {
        case name, notes, date, lat, lng
        case googlePlaceId = "google_place_id"
        case sortOrder = "sort_order"
        case rating
        case visitedAt = "visited_at"
        case legId = "leg_id"
        case isRouteAnchor = "is_route_anchor"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(lat, forKey: .lat)
        try c.encodeIfPresent(lng, forKey: .lng)
        try c.encodeIfPresent(googlePlaceId, forKey: .googlePlaceId)
        try c.encodeIfPresent(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(isRouteAnchor, forKey: .isRouteAnchor)

        if clearNotes { try c.encodeNil(forKey: .notes) } else { try c.encodeIfPresent(notes, forKey: .notes) }
        if clearDate { try c.encodeNil(forKey: .date) } else { try c.encodeIfPresent(date, forKey: .date) }
        if clearRating { try c.encodeNil(forKey: .rating) } else { try c.encodeIfPresent(rating, forKey: .rating) }
        if clearVisitedAt { try c.encodeNil(forKey: .visitedAt) } else { try c.encodeIfPresent(visitedAt, forKey: .visitedAt) }
        if clearLegId { try c.encodeNil(forKey: .legId) } else { try c.encodeIfPresent(legId, forKey: .legId) }
    }
}

protocol TripPlacesServiceProtocol {
    func fetchPlaces(tripId: Int64) async throws -> [TripPlace]
    func createPlace(payload: TripPlaceInsert) async throws -> TripPlace
    func updatePlace(id: Int64, update: TripPlaceUpdate) async throws
    func deletePlace(id: Int64) async throws
    func reorderPlaces(tripId: Int64, placeIds: [Int64]) async throws -> [TripPlace]
}

final class TripPlacesService: TripPlacesServiceProtocol {
    private let client = SupabaseManager.client

    func fetchPlaces(tripId: Int64) async throws -> [TripPlace] {
        try await client
            .from("trip_places")
            .select()
            .eq("trip_id", value: Int(tripId))
            .order("sort_order")
            .execute()
            .value
    }

    func createPlace(payload: TripPlaceInsert) async throws -> TripPlace {
        try await client
            .from("trip_places")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updatePlace(id: Int64, update: TripPlaceUpdate) async throws {
        try await client
            .from("trip_places")
            .update(update)
            .eq("id", value: Int(id))
            .execute()
    }

    func deletePlace(id: Int64) async throws {
        try await client
            .from("trip_places")
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    func reorderPlaces(tripId: Int64, placeIds: [Int64]) async throws -> [TripPlace] {
        struct Params: Encodable {
            let pTripId: Int64
            let pPlaceIds: [Int64]
            enum CodingKeys: String, CodingKey {
                case pTripId = "p_trip_id"
                case pPlaceIds = "p_place_ids"
            }
        }
        return try await client
            .rpc("reorder_trip_places_atomic", params: Params(pTripId: tripId, pPlaceIds: placeIds))
            .execute()
            .value
    }
}
