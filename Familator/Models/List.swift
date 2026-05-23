import Foundation

struct FamilatorList: Codable, Identifiable {
    var id: Int64
    var ownerId: UUID
    var name: String
    var description: String?
    var isShared: Bool
    var isInbox: Bool?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case description
        case isShared = "is_shared"
        case isInbox = "is_inbox"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
