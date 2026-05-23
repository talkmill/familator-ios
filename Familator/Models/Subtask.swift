import Foundation

struct Subtask: Codable, Identifiable {
    var id: Int64
    var todoId: Int64
    var title: String
    var status: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case todoId = "todo_id"
        case title
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
    }

    static let statusPending = "pending"
    static let statusCompleted = "completed"
}
