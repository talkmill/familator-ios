import Foundation

struct Note: Codable, Identifiable {
    var id: Int64
    var listId: Int64
    var title: String
    var content: JSONValue
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case title
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static let untitledTitle = "Untitled"

    static let emptyDocument: JSONValue = .object([
        "type": .string("doc"),
        "content": .array([
            .object(["type": .string("paragraph")]),
        ]),
    ])
}

struct NoteSummary: Codable, Identifiable {
    var id: Int64
    var title: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
    }
}

struct NoteTodoLink: Codable, Hashable {
    var noteId: Int64
    var todoId: Int64

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case todoId = "todo_id"
    }
}

struct LinkedTodoSummary: Codable, Identifiable, Hashable {
    var id: Int64
    var title: String
    var status: String
}
