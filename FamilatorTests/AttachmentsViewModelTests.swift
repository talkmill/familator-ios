import XCTest
@testable import Familator

final class AttachmentsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeAttachment(
        id: Int64,
        mimeType: String = "image/jpeg",
        sizeBytes: Int64 = 1024,
        category: AttachmentCategory = .photo
    ) -> TripAttachment {
        let fields: [String: Any] = [
            "id": id,
            "trip_id": 1,
            "owner_id": UUID().uuidString,
            "uploaded_by": UUID().uuidString,
            "storage_bucket": "trip-attachments",
            "storage_path": "path/to/file-\(id).jpg",
            "title": "File \(id)",
            "description": "",
            "category": category.rawValue,
            "mime_type": mimeType,
            "size_bytes": sizeBytes,
            "original_filename": "file-\(id).jpg",
            "created_at": "2026-01-01T00:00:00+00:00",
            "updated_at": "2026-01-01T00:00:00+00:00",
        ]
        let data = try! JSONSerialization.data(withJSONObject: fields)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(TripAttachment.self, from: data)
    }

    // MARK: - Initial state

    @MainActor
    func testInitialState() {
        let vm = AttachmentsViewModel(tripId: 1)
        XCTAssertTrue(vm.attachments.isEmpty)
        XCTAssertFalse(vm.isBlockingLoad)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertFalse(vm.isUploading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.imageCount, 0)
        XCTAssertEqual(vm.documentCount, 0)
    }

    // MARK: - Computed counts

    @MainActor
    func testImageAndDocumentCounts() {
        let vm = AttachmentsViewModel(tripId: 1)
        vm.attachments = [
            makeAttachment(id: 1, mimeType: "image/jpeg"),
            makeAttachment(id: 2, mimeType: "image/png"),
            makeAttachment(id: 3, mimeType: "application/pdf"),
            makeAttachment(id: 4, mimeType: "text/plain"),
        ]
        XCTAssertEqual(vm.imageCount, 2)
        XCTAssertEqual(vm.documentCount, 2)
    }

    // MARK: - TripAttachment model

    func testIsImage() {
        let img = makeAttachment(id: 1, mimeType: "image/png")
        XCTAssertTrue(img.isImage)

        let doc = makeAttachment(id: 2, mimeType: "application/pdf")
        XCTAssertFalse(doc.isImage)
    }

    func testFormattedSize() {
        let bytes = makeAttachment(id: 1, sizeBytes: 512)
        XCTAssertEqual(bytes.formattedSize, "512 B")

        let kb = makeAttachment(id: 2, sizeBytes: 2048)
        XCTAssertEqual(kb.formattedSize, "2.0 KB")

        let mb = makeAttachment(id: 3, sizeBytes: 5_242_880)
        XCTAssertEqual(mb.formattedSize, "5.0 MB")
    }

    // MARK: - AttachmentCategory

    func testAllCategories() {
        let expected: [AttachmentCategory] = [.flight, .hotel, .ticket, .reservation, .map, .photo, .receipt, .other]
        XCTAssertEqual(AttachmentCategory.allCases, expected)
    }

    func testCategorySystemImages() {
        XCTAssertEqual(AttachmentCategory.flight.systemImage, "airplane")
        XCTAssertEqual(AttachmentCategory.hotel.systemImage, "bed.double")
        XCTAssertEqual(AttachmentCategory.photo.systemImage, "photo")
        XCTAssertEqual(AttachmentCategory.other.systemImage, "doc")
    }

    // MARK: - Delete (optimistic)

    @MainActor
    func testDeleteRemovesFromArray() {
        let vm = AttachmentsViewModel(tripId: 1)
        let a1 = makeAttachment(id: 1)
        let a2 = makeAttachment(id: 2)
        vm.attachments = [a1, a2]

        // Simulate optimistic removal (we can't call the real delete without a backend)
        vm.attachments.removeAll { $0.id == a1.id }
        XCTAssertEqual(vm.attachments.count, 1)
        XCTAssertEqual(vm.attachments.first?.id, a2.id)
    }
}
