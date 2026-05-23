import Foundation

struct Workspace: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var code: String
    var color: String
    let ownerId: UUID
    let isPersonal: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, code, color
        case ownerId = "owner_id"
        case isPersonal = "is_personal"
        case createdAt = "created_at"
    }
}
