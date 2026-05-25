import Foundation

@MainActor
final class AttachmentsViewModel: ObservableObject {
    let tripId: Int64

    @Published var attachments: [TripAttachment] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var isUploading = false
    @Published var errorMessage: String?

    private let service: TripAttachmentsServiceProtocol
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0
    private var signedURLCache: [String: (url: URL, expiry: Date)] = [:]

    init(tripId: Int64, service: TripAttachmentsServiceProtocol = TripAttachmentsService()) {
        self.tripId = tripId
        self.service = service
    }

    var imageCount: Int {
        attachments.filter(\.isImage).count
    }

    var documentCount: Int {
        attachments.filter { !$0.isImage }.count
    }

    func load() async {
        let showBlocking = !initialLoadAttemptCompleted
        loadSequence &+= 1
        let sequence = loadSequence

        if showBlocking {
            isBlockingLoad = true
        } else {
            isRefreshing = true
        }

        defer {
            if sequence == loadSequence {
                initialLoadAttemptCompleted = true
                isBlockingLoad = false
                isRefreshing = false
            }
        }

        do {
            let fetched = try await service.fetchAttachments(tripId: tripId)
            guard sequence == loadSequence else { return }
            attachments = fetched
            errorMessage = nil
        } catch {
            guard sequence == loadSequence else { return }
            errorMessage = error.localizedDescription
        }
    }

    func upload(data: Data, filename: String, mimeType: String, category: AttachmentCategory = .other) async {
        isUploading = true
        defer { isUploading = false }

        do {
            let attachment = try await service.uploadAttachment(
                tripId: tripId,
                fileData: data,
                filename: filename,
                mimeType: mimeType,
                category: category
            )
            attachments.insert(attachment, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ attachment: TripAttachment) async {
        let snapshot = attachments
        attachments.removeAll { $0.id == attachment.id }
        do {
            try await service.deleteAttachment(attachment)
        } catch {
            attachments = snapshot
            errorMessage = error.localizedDescription
        }
    }

    func updateMetadata(
        _ attachment: TripAttachment,
        title: String? = nil,
        description: String? = nil,
        category: AttachmentCategory? = nil
    ) async {
        guard let index = attachments.firstIndex(where: { $0.id == attachment.id }) else { return }
        let old = attachments[index]

        if let title { attachments[index].title = title }
        if let description { attachments[index].description = description }
        if let category { attachments[index].category = category }

        let update = TripAttachmentUpdate(
            title: title,
            description: description,
            category: category
        )

        guard title != nil || description != nil || category != nil else { return }

        do {
            try await service.updateAttachment(id: attachment.id, update: update)
        } catch {
            attachments[index] = old
            errorMessage = error.localizedDescription
        }
    }

    func signedURL(for attachment: TripAttachment) async throws -> URL {
        let key = attachment.storagePath
        if let cached = signedURLCache[key], cached.expiry > Date() {
            return cached.url
        }
        let url = try await service.createSignedURL(storagePath: key)
        // Cache with 4-minute TTL (URLs expire in 5 min)
        signedURLCache[key] = (url, Date().addingTimeInterval(240))
        return url
    }

    func downloadFile(for attachment: TripAttachment) async throws -> URL {
        let data = try await service.downloadFile(storagePath: attachment.storagePath)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // Use lastPathComponent to strip any path-traversal segments
        let safeName = (attachment.originalFilename as NSString).lastPathComponent
        let fileURL = tempDir.appendingPathComponent(safeName)
        try data.write(to: fileURL)
        return fileURL
    }
}
