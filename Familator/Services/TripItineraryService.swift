import Foundation
import Supabase

struct TripItineraryItemInsert: Encodable {
    let tripId: Int64
    let workspaceId: UUID
    let ownerId: UUID
    let itemType: ItineraryItemType
    let title: String
    let sortOrder: Int
    var description: String?
    var date: String?
    var startTime: String?
    var endTime: String?
    var confirmationNumber: String?
    var provider: String?
    var legId: Int64?
    var placeId: Int64?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case workspaceId = "workspace_id"
        case ownerId = "owner_id"
        case itemType = "item_type"
        case title
        case sortOrder = "sort_order"
        case description
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case confirmationNumber = "confirmation_number"
        case provider
        case legId = "leg_id"
        case placeId = "place_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tripId, forKey: .tripId)
        try c.encode(workspaceId, forKey: .workspaceId)
        try c.encode(ownerId, forKey: .ownerId)
        try c.encode(itemType, forKey: .itemType)
        try c.encode(title, forKey: .title)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(date, forKey: .date)
        try c.encodeIfPresent(startTime, forKey: .startTime)
        try c.encodeIfPresent(endTime, forKey: .endTime)
        try c.encodeIfPresent(confirmationNumber, forKey: .confirmationNumber)
        try c.encodeIfPresent(provider, forKey: .provider)
        try c.encodeIfPresent(legId, forKey: .legId)
        try c.encodeIfPresent(placeId, forKey: .placeId)
    }
}

struct TripItineraryItemUpdate: Encodable {
    var itemType: ItineraryItemType?
    var title: String?
    var description: String?
    var date: String?
    var startTime: String?
    var endTime: String?
    var confirmationNumber: String?
    var provider: String?
    var legId: Int64?
    var placeId: Int64?
    var sortOrder: Int?
    var clearDescription: Bool = false
    var clearDate: Bool = false
    var clearStartTime: Bool = false
    var clearEndTime: Bool = false
    var clearConfirmationNumber: Bool = false
    var clearProvider: Bool = false
    var clearLegId: Bool = false
    var clearPlaceId: Bool = false

    enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case title
        case description
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case confirmationNumber = "confirmation_number"
        case provider
        case legId = "leg_id"
        case placeId = "place_id"
        case sortOrder = "sort_order"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(itemType, forKey: .itemType)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(sortOrder, forKey: .sortOrder)

        if clearDescription { try c.encodeNil(forKey: .description) } else { try c.encodeIfPresent(description, forKey: .description) }
        if clearDate { try c.encodeNil(forKey: .date) } else { try c.encodeIfPresent(date, forKey: .date) }
        if clearStartTime { try c.encodeNil(forKey: .startTime) } else { try c.encodeIfPresent(startTime, forKey: .startTime) }
        if clearEndTime { try c.encodeNil(forKey: .endTime) } else { try c.encodeIfPresent(endTime, forKey: .endTime) }
        if clearConfirmationNumber { try c.encodeNil(forKey: .confirmationNumber) } else { try c.encodeIfPresent(confirmationNumber, forKey: .confirmationNumber) }
        if clearProvider { try c.encodeNil(forKey: .provider) } else { try c.encodeIfPresent(provider, forKey: .provider) }
        if clearLegId { try c.encodeNil(forKey: .legId) } else { try c.encodeIfPresent(legId, forKey: .legId) }
        if clearPlaceId { try c.encodeNil(forKey: .placeId) } else { try c.encodeIfPresent(placeId, forKey: .placeId) }
    }
}

final class TripItineraryService {
    private let client = SupabaseManager.client

    func fetchItems(tripId: Int64) async throws -> [TripItineraryItem] {
        try await client
            .from("trip_itinerary_items")
            .select()
            .eq("trip_id", value: Int(tripId))
            .order("date")
            .order("start_time")
            .order("sort_order")
            .execute()
            .value
    }

    func createItem(payload: TripItineraryItemInsert) async throws -> TripItineraryItem {
        try await client
            .from("trip_itinerary_items")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateItem(id: Int64, update: TripItineraryItemUpdate) async throws {
        try await client
            .from("trip_itinerary_items")
            .update(update)
            .eq("id", value: Int(id))
            .execute()
    }

    func deleteItem(id: Int64) async throws {
        try await client
            .from("trip_itinerary_items")
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    func reorderItems(tripId: Int64, itemIds: [Int64]) async throws -> [TripItineraryItem] {
        struct Params: Encodable {
            let pTripId: Int64
            let pItemIds: [Int64]
            enum CodingKeys: String, CodingKey {
                case pTripId = "p_trip_id"
                case pItemIds = "p_item_ids"
            }
        }
        return try await client
            .rpc("reorder_trip_itinerary_items_atomic", params: Params(pTripId: tripId, pItemIds: itemIds))
            .execute()
            .value
    }
}
