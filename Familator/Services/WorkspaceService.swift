import Foundation
import Supabase

protocol WorkspaceServiceProtocol {
    func fetchWorkspaces() async throws -> [Workspace]
    func updateActiveWorkspace(userId: UUID, workspaceId: String) async throws
    func fetchActiveWorkspaceId(userId: UUID) async throws -> String?
}

final class WorkspaceService: WorkspaceServiceProtocol {
    private let client = SupabaseManager.client

    /// Fetches all workspaces the authenticated user is a member of.
    /// RLS on the `workspaces` table scopes results to membership automatically.
    func fetchWorkspaces() async throws -> [Workspace] {
        let workspaces: [Workspace] = try await client
            .from("workspaces")
            .select()
            .order("created_at")
            .execute()
            .value
        return workspaces
    }

    /// Updates the user's active workspace in their profile.
    func updateActiveWorkspace(userId: UUID, workspaceId: String) async throws {
        struct Payload: Encodable {
            let activeWorkspaceId: String
            enum CodingKeys: String, CodingKey {
                case activeWorkspaceId = "active_workspace_id"
            }
        }
        try await client
            .from("profiles")
            .update(Payload(activeWorkspaceId: workspaceId))
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Fetches the user's current active workspace ID from their profile.
    func fetchActiveWorkspaceId(userId: UUID) async throws -> String? {
        struct Row: Decodable {
            let activeWorkspaceId: String?
            enum CodingKeys: String, CodingKey {
                case activeWorkspaceId = "active_workspace_id"
            }
        }
        let rows: [Row] = try await client
            .from("profiles")
            .select("active_workspace_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.activeWorkspaceId
    }
}
