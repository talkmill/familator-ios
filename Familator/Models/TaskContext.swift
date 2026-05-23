import Foundation

struct TaskContext: Decodable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
