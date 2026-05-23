import Foundation

struct SearchUser: Codable, Identifiable {
    var id: UUID
    var email: String?
    var displayName: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}
