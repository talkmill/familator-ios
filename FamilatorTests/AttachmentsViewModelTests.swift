import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockTripAttachmentsService: TripAttachmentsServiceProtocol {
    var attachmentsToReturn: [TripAttachment] = []
    var uploadedAttachmentToReturn: TripAttachment?
    var signedURLToReturn: URL = URL(string: "https://example.com/signed")!
    var downloadDataToReturn: Data = Data()
    var errorToThrow: Error?
    var fetchAttachmentsCalls: [Int64] = []
    var uploadCalls: [(tripId: Int64, filename: String, mimeType: String, category: AttachmentCategory)] = []
    var updateCalls: [(id: Int64, update: TripAttachmentUpdate)] = []
    var deleteCalls: [TripAttachment] = []
    var signedURLCalls: [String] = []
    var downloadCalls: [String] = []

    func fetchAttachments(tripId: Int64) async throws -> [TripAttachment] {
        fetchAttachmentsCalls.append(tripId)
        if let error = errorToThrow { throw error }
        return attachmentsToReturn
    }

    func uploadAttachment(tripId: Int64, fileData: Data, filename: String, mimeType: String, category: AttachmentCategory) async throws -> TripAttachment {
        uploadCalls.append((tripId, filename, mimeType, category))
        if let error = errorToThrow { throw error }
        guard let attachment = uploadedAttachmentToReturn else { XCTFail("uploadedAttachmentToReturn not set"); throw MockError.notConfigured }
        return attachment
    }

    func updateAttachment(id: Int64, update: TripAttachmentUpdate) async throws {
        updateCalls.append((id, update))
        if let error = errorToThrow { throw error }
    }

    func deleteAttachment(_ attachment: TripAttachment) async throws {
        deleteCalls.append(attachment)
        if let error = errorToThrow { throw error }
    }

    func createSignedURL(storagePath: String) async throws -> URL {
        signedURLCalls.append(storagePath)
        if let error = errorToThrow { throw error }
        return signedURLToReturn
    }

    func downloadFile(storagePath: String) async throws -> Data {
        downloadCalls.append(storagePath)
        if let error = errorToThrow { throw error }
        return downloadDataToReturn
    }
}

@MainActor
final class AttachmentsViewModelTests: XCTestCase {
    private var sut: AttachmentsViewModel!
    private var mockService: MockTripAttachmentsService!

    override func setUp() {
        super.setUp()
        mockService = MockTripAttachmentsService()
        sut = AttachmentsViewModel(tripId: 1, service: mockService)
    }

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

    func testInitialState() {
        XCTAssertTrue(sut.attachments.isEmpty)
        XCTAssertFalse(sut.isBlockingLoad)
        XCTAssertFalse(sut.isRefreshing)
        XCTAssertFalse(sut.isUploading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.imageCount, 0)
        XCTAssertEqual(sut.documentCount, 0)
    }

    // MARK: - Computed counts

    func testImageAndDocumentCounts() {
        sut.attachments = [
            makeAttachment(id: 1, mimeType: "image/jpeg"),
            makeAttachment(id: 2, mimeType: "image/png"),
            makeAttachment(id: 3, mimeType: "application/pdf"),
            makeAttachment(id: 4, mimeType: "text/plain"),
        ]
        XCTAssertEqual(sut.imageCount, 2)
        XCTAssertEqual(sut.documentCount, 2)
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

    // MARK: - Load via mock service

    func testLoadFetchesAttachmentsFromService() async {
        let a1 = makeAttachment(id: 1)
        let a2 = makeAttachment(id: 2)
        mockService.attachmentsToReturn = [a1, a2]

        await sut.load()

        XCTAssertEqual(sut.attachments.count, 2)
        XCTAssertEqual(mockService.fetchAttachmentsCalls, [1])
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadSetsErrorOnFailure() async {
        mockService.errorToThrow = NSError(domain: "test", code: 42)

        await sut.load()

        XCTAssertTrue(sut.attachments.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Delete via mock service

    func testDeleteCallsServiceAndRemovesFromArray() async {
        let a1 = makeAttachment(id: 1)
        let a2 = makeAttachment(id: 2)
        sut.attachments = [a1, a2]

        await sut.delete(a1)

        XCTAssertEqual(sut.attachments.count, 1)
        XCTAssertEqual(sut.attachments.first?.id, a2.id)
        XCTAssertEqual(mockService.deleteCalls.count, 1)
        XCTAssertEqual(mockService.deleteCalls[0].id, a1.id)
    }

    func testDeleteRestoresOnFailure() async {
        let a1 = makeAttachment(id: 1)
        let a2 = makeAttachment(id: 2)
        sut.attachments = [a1, a2]
        mockService.errorToThrow = NSError(domain: "test", code: 1)

        await sut.delete(a1)

        XCTAssertEqual(sut.attachments.count, 2)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Upload via mock service

    func testUploadInsertsAtFront() async {
        let existing = makeAttachment(id: 1)
        sut.attachments = [existing]
        let uploaded = makeAttachment(id: 2)
        mockService.uploadedAttachmentToReturn = uploaded

        await sut.upload(data: Data(), filename: "test.jpg", mimeType: "image/jpeg")

        XCTAssertEqual(sut.attachments.count, 2)
        XCTAssertEqual(sut.attachments.first?.id, uploaded.id)
        XCTAssertEqual(mockService.uploadCalls.count, 1)
        XCTAssertEqual(mockService.uploadCalls[0].filename, "test.jpg")
    }

    func testUploadSetsErrorOnFailure() async {
        mockService.errorToThrow = NSError(domain: "test", code: 1)

        await sut.upload(data: Data(), filename: "fail.jpg", mimeType: "image/jpeg")

        XCTAssertTrue(sut.attachments.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isUploading)
    }
}
