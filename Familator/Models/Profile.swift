import Foundation

struct Profile: Codable, Identifiable {
    var id: Int64
    var userId: UUID
    var displayName: String?
    var avatarUrl: String?
    var activeWorkspaceId: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case activeWorkspaceId = "active_workspace_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
