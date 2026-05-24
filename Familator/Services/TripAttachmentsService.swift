import Foundation
import Supabase

protocol TripAttachmentsServiceProtocol {
    func fetchAttachments(tripId: Int64) async throws -> [TripAttachment]
    func uploadAttachment(tripId: Int64, fileData: Data, filename: String, mimeType: String, category: AttachmentCategory) async throws -> TripAttachment
    func updateAttachment(id: Int64, update: TripAttachmentUpdate) async throws
    func deleteAttachment(_ attachment: TripAttachment) async throws
    func createSignedURL(storagePath: String) async throws -> URL
    func downloadFile(storagePath: String) async throws -> Data
}

final class TripAttachmentsService: TripAttachmentsServiceProtocol {
    private let client = SupabaseManager.client
    private let bucket = "trip-attachments"

    func fetchAttachments(tripId: Int64) async throws -> [TripAttachment] {
        let attachments: [TripAttachment] = try await client
            .from("trip_attachments")
            .select()
            .eq("trip_id", value: Int(tripId))
            .order("created_at", ascending: false)
            .execute()
            .value
        return attachments
    }

    func uploadAttachment(
        tripId: Int64,
        fileData: Data,
        filename: String,
        mimeType: String,
        category: AttachmentCategory = .other
    ) async throws -> TripAttachment {
        // Use the authenticated user's ID (matches auth.uid() in RLS policies)
        let currentUserId = try await client.auth.session.user.id

        let ext = (filename as NSString).pathExtension
        let safeExt = ext.isEmpty ? "" : ".\(ext.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ext)"
        let storagePath = "\(currentUserId.uuidString)/\(tripId)/\(UUID().uuidString)\(safeExt)"

        try await uploadToStorage(path: storagePath, data: fileData, mimeType: mimeType)

        let title = (filename as NSString).deletingPathExtension

        let insert = TripAttachmentInsert(
            tripId: tripId,
            ownerId: currentUserId,
            uploadedBy: currentUserId,
            storageBucket: bucket,
            storagePath: storagePath,
            title: String(title.prefix(120)),
            description: "",
            category: category,
            mimeType: mimeType,
            sizeBytes: Int64(fileData.count),
            originalFilename: String(filename.prefix(255))
        )

        do {
            let attachment: TripAttachment = try await client
                .from("trip_attachments")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            return attachment
        } catch {
            try? await client.storage.from(bucket).remove(paths: [storagePath])
            throw error
        }
    }

    func updateAttachment(id: Int64, update: TripAttachmentUpdate) async throws {
        try await client
            .from("trip_attachments")
            .update(update)
            .eq("id", value: Int(id))
            .execute()
    }

    func deleteAttachment(_ attachment: TripAttachment) async throws {
        try await client
            .from("trip_attachments")
            .delete()
            .eq("id", value: Int(attachment.id))
            .execute()

        try? await client.storage
            .from(bucket)
            .remove(paths: [attachment.storagePath])
    }

    func createSignedURL(storagePath: String) async throws -> URL {
        try await client.storage
            .from(bucket)
            .createSignedURL(path: storagePath, expiresIn: 300)
    }

    func downloadFile(storagePath: String) async throws -> Data {
        try await client.storage
            .from(bucket)
            .download(path: storagePath)
    }

    // MARK: - Direct storage upload (bypasses QUIC)

    // Dedicated ephemeral session that has never negotiated HTTP/3.
    // URLSession.shared caches QUIC connections from the SDK's other
    // calls, so even requests with assumesHTTP3Capable=false reuse
    // the broken QUIC path. An ephemeral session starts clean.
    private static let uploadSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    private func uploadToStorage(path: String, data: Data, mimeType: String) async throws {
        let token = try await client.auth.session.accessToken

        let storageURL = AppConfig.supabaseURL
            .appendingPathComponent("storage/v1/object")
            .appendingPathComponent(bucket)
            .appendingPathComponent(path)

        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\"; filename=\"\(path)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: storageURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "Cache-Control")
        request.assumesHTTP3Capable = false
        request.httpBody = body

        let (responseData, response) = try await Self.uploadSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: responseData, encoding: .utf8) ?? "Upload failed"
            throw NSError(
                domain: "TripAttachmentsService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
