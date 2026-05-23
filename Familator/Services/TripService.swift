import Foundation
import Supabase

final class TripService {
    private let client = SupabaseManager.client

    func fetchTrips(workspaceId: String) async throws -> [Trip] {
        let trips: [Trip] = try await client
            .from("trips")
            .select()
            .eq("workspace_id", value: workspaceId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return trips
    }

    /// Creates a trip with a backing list. On trip-insert failure the orphaned list is cleaned up.
    func createTrip(ownerId: UUID, destination: String, workspaceId: String) async throws -> Trip {
        struct ListPayload: Encodable {
            let ownerId: UUID
            let name: String
            let workspaceId: String
            enum CodingKeys: String, CodingKey {
                case ownerId = "owner_id"
                case name
                case workspaceId = "workspace_id"
            }
        }

        let list: FamilatorList = try await client
            .from("lists")
            .insert(ListPayload(ownerId: ownerId, name: destination, workspaceId: workspaceId))
            .select()
            .single()
            .execute()
            .value

        struct TripPayload: Encodable {
            let listId: Int64
            let ownerId: UUID
            let destination: String
            let workspaceId: String
            enum CodingKeys: String, CodingKey {
                case listId = "list_id"
                case ownerId = "owner_id"
                case destination
                case workspaceId = "workspace_id"
            }
        }

        do {
            let trip: Trip = try await client
                .from("trips")
                .insert(TripPayload(listId: list.id, ownerId: ownerId, destination: destination, workspaceId: workspaceId))
                .select()
                .single()
                .execute()
                .value
            return trip
        } catch {
            // Clean up orphaned list
            _ = try? await client.from("lists").delete().eq("id", value: Int(list.id)).execute()
            throw error
        }
    }

    /// Deletes a trip by deleting its backing list (cascades to the trip row).
    func deleteTrip(_ trip: Trip) async throws {
        try await client
            .from("lists")
            .delete()
            .eq("id", value: Int(trip.listId))
            .execute()
    }

    func fetchTrip(id: Int64) async throws -> Trip? {
        let trips: [Trip] = try await client
            .from("trips")
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value
        return trips.first
    }

    func updateTripDestination(id: Int64, destination: String) async throws {
        struct Payload: Encodable {
            let destination: String
        }
        try await client
            .from("trips")
            .update(Payload(destination: destination))
            .eq("id", value: Int(id))
            .execute()
    }

    func updateTripStartDate(id: Int64, startDate: String?) async throws {
        struct Payload: Encodable {
            let startDate: String?
            enum CodingKeys: String, CodingKey {
                case startDate = "start_date"
            }
        }
        try await client
            .from("trips")
            .update(Payload(startDate: startDate))
            .eq("id", value: Int(id))
            .execute()
    }

    func updateTripEndDate(id: Int64, endDate: String?) async throws {
        struct Payload: Encodable {
            let endDate: String?
            enum CodingKeys: String, CodingKey {
                case endDate = "end_date"
            }
        }
        try await client
            .from("trips")
            .update(Payload(endDate: endDate))
            .eq("id", value: Int(id))
            .execute()
    }

    func updateTripTransportMode(id: Int64, transportMode: TransportMode) async throws {
        struct Payload: Encodable {
            let transportMode: TransportMode
            enum CodingKeys: String, CodingKey {
                case transportMode = "transport_mode"
            }
        }
        try await client
            .from("trips")
            .update(Payload(transportMode: transportMode))
            .eq("id", value: Int(id))
            .execute()
    }
}
