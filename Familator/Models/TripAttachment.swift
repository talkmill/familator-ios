import Foundation

enum AttachmentCategory: String, Codable, CaseIterable, Identifiable {
    case flight
    case hotel
    case ticket
    case reservation
    case map
    case photo
    case receipt
    case other

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "bed.double"
        case .ticket: return "ticket"
        case .reservation: return "calendar.badge.clock"
        case .map: return "map"
        case .photo: return "photo"
        case .receipt: return "receipt"
        case .other: return "doc"
        }
    }
}

struct TripAttachment: Codable, Identifiable {
    var id: Int64
    var tripId: Int64
    var ownerId: UUID
    var uploadedBy: UUID
    var storageBucket: String
    var storagePath: String
    var title: String
    var description: String
    var category: AttachmentCategory
    var mimeType: String
    var sizeBytes: Int64
    var originalFilename: String
    var itineraryItemId: Int64?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case ownerId = "owner_id"
        case uploadedBy = "uploaded_by"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case title
        case description
        case category
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case originalFilename = "original_filename"
        case itineraryItemId = "itinerary_item_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    var formattedSize: String {
        if sizeBytes < 1024 {
            return "\(sizeBytes) B"
        } else if sizeBytes < 1_048_576 {
            return String(format: "%.1f KB", Double(sizeBytes) / 1024)
        } else if sizeBytes < 1_073_741_824 {
            return String(format: "%.1f MB", Double(sizeBytes) / 1_048_576)
        } else {
            return String(format: "%.1f GB", Double(sizeBytes) / 1_073_741_824)
        }
    }
}

struct TripAttachmentInsert: Encodable {
    let tripId: Int64
    let ownerId: UUID
    let uploadedBy: UUID
    let storageBucket: String
    let storagePath: String
    let title: String
    let description: String
    let category: AttachmentCategory
    let mimeType: String
    let sizeBytes: Int64
    let originalFilename: String

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case ownerId = "owner_id"
        case uploadedBy = "uploaded_by"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case title
        case description
        case category
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case originalFilename = "original_filename"
    }
}

struct TripAttachmentUpdate: Encodable {
    var title: String?
    var description: String?
    var category: AttachmentCategory?
    var itineraryItemId: Int64?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case category
        case itineraryItemId = "itinerary_item_id"
    }
}
