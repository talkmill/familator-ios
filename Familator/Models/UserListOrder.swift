import Foundation

struct UserListOrder: Codable {
    var userId: UUID
    var listId: Int64
    var position: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case listId = "list_id"
        case position
    }
}
