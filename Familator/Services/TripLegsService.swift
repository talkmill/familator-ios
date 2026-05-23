import Foundation
import Supabase

struct TripLegInsert: Encodable {
    let tripId: Int64
    let name: String
    let sortOrder: Int
    var transportMode: TransportMode?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case name
        case sortOrder = "sort_order"
        case transportMode = "transport_mode"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tripId, forKey: .tripId)
        try c.encode(name, forKey: .name)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(transportMode, forKey: .transportMode)
    }
}

struct TripLegUpdate: Encodable {
    var name: String?
    var sortOrder: Int?
    var transportMode: TransportMode?

    enum CodingKeys: String, CodingKey {
        case name
        case sortOrder = "sort_order"
        case transportMode = "transport_mode"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(transportMode, forKey: .transportMode)
    }
}

final class TripLegsService {
    private let client = SupabaseManager.client

    func fetchLegs(tripId: Int64) async throws -> [TripLeg] {
        try await client
            .from("trip_legs")
            .select()
            .eq("trip_id", value: Int(tripId))
            .order("sort_order")
            .execute()
            .value
    }

    func createLeg(payload: TripLegInsert) async throws -> TripLeg {
        try await client
            .from("trip_legs")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateLeg(id: Int64, update: TripLegUpdate) async throws {
        try await client
            .from("trip_legs")
            .update(update)
            .eq("id", value: Int(id))
            .execute()
    }

    func deleteLeg(id: Int64) async throws {
        try await client
            .from("trip_legs")
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    func reorderLegs(tripId: Int64, legIds: [Int64]) async throws -> [TripLeg] {
        struct Params: Encodable {
            let pTripId: Int64
            let pLegIds: [Int64]
            enum CodingKeys: String, CodingKey {
                case pTripId = "p_trip_id"
                case pLegIds = "p_leg_ids"
            }
        }
        return try await client
            .rpc("reorder_trip_legs_atomic", params: Params(pTripId: tripId, pLegIds: legIds))
            .execute()
            .value
    }
}
