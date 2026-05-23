import Foundation

struct CurrentListItem: Decodable, Identifiable {
    let id: Int64
    let userId: UUID
    let todoId: Int64
    let position: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case todoId = "todo_id"
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

