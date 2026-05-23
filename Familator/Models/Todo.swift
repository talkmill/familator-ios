import Foundation

struct Todo: Decodable, Identifiable {
    var id: Int64
    var listId: Int64
    var title: String
    var description: String?
    var status: String
    var priority: String?
    var dueDate: Date?
    var plannedDate: Date?
    var recurrence: TodoRecurrenceJSON?
    var recurrencePaused: Bool?
    var recurrenceSeriesId: UUID?
    var kind: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var contexts: [TaskContext]

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case title
        case description
        case status
        case priority
        case dueDate = "due_date"
        case plannedDate = "planned_date"
        case recurrence
        case recurrencePaused = "recurrence_paused"
        case recurrenceSeriesId = "recurrence_series_id"
        case kind
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        listId = try c.decode(Int64.self, forKey: .listId)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decode(String.self, forKey: .status)
        priority = try c.decodeIfPresent(String.self, forKey: .priority)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        plannedDate = try c.decodeIfPresent(Date.self, forKey: .plannedDate)
        if let decoded = try? c.decodeIfPresent(TodoRecurrenceJSON.self, forKey: .recurrence), decoded.isValidRule {
            recurrence = decoded
        } else {
            recurrence = nil
        }
        recurrencePaused = try c.decodeIfPresent(Bool.self, forKey: .recurrencePaused)
        recurrenceSeriesId = try c.decodeIfPresent(UUID.self, forKey: .recurrenceSeriesId)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        contexts = []
    }

    static let statusPending = "pending"
    static let statusCompleted = "completed"
    static let priorityLow = "low"
    static let priorityMedium = "medium"
    static let priorityHigh = "high"

    var isRecurrencePaused: Bool { recurrencePaused ?? false }

    var hasRecurrencePayload: Bool { recurrence?.isValidRule == true }

    /// Pending todo with a recurrence rule and not paused.
    var isActiveRecurring: Bool {
        hasRecurrencePayload && status == Todo.statusPending && !isRecurrencePaused
    }
}
