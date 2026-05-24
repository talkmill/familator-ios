import XCTest
import Nuke
@testable import Familator

final class MockSignedURLProvider: SignedURLProviding {
    var urlsToReturn: [String: URL] = [:]
    var callCount = 0
    var errorToThrow: Error?
    var artificialDelay: UInt64 = 0
    private let lock = NSLock()

    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        lock.lock()
        callCount += 1
        lock.unlock()

        if artificialDelay > 0 {
            try? await Task.sleep(nanoseconds: artificialDelay)
        }

        if let error = errorToThrow { throw error }

        let key = "\(bucket)/\(path)"
        guard let url = urlsToReturn[key] else {
            return URL(string: "https://example.com/signed/\(path)?token=\(UUID().uuidString)")!
        }
        return url
    }
}

final class ImageCacheServiceTests: XCTestCase {
    private var mockProvider: MockSignedURLProvider!

    override func setUp() {
        super.setUp()
        mockProvider = MockSignedURLProvider()
    }

    func testImageRequestCacheKeyUsesStoragePath() async throws {
        let service = ImageCacheService(urlProvider: mockProvider)

        let request = try await service.imageRequest(bucket: "trip-attachments", storagePath: "photos/img.jpg")

        let cacheKey = request.userInfo[.imageIdKey] as? String
        XCTAssertEqual(cacheKey, "trip-attachments/photos/img.jpg")
    }

    func testDifferentPathsProduceDifferentCacheKeys() async throws {
        let service = ImageCacheService(urlProvider: mockProvider)

        let request1 = try await service.imageRequest(bucket: "bucket", storagePath: "a.jpg")
        let request2 = try await service.imageRequest(bucket: "bucket", storagePath: "b.jpg")

        let key1 = request1.userInfo[.imageIdKey] as? String
        let key2 = request2.userInfo[.imageIdKey] as? String
        XCTAssertNotEqual(key1, key2)
        XCTAssertEqual(key1, "bucket/a.jpg")
        XCTAssertEqual(key2, "bucket/b.jpg")
    }

    func testConcurrentRequestsForSamePathCoalesceURLFetches() async throws {
        mockProvider.artificialDelay = 50_000_000 // 50ms to ensure overlap
        let service = ImageCacheService(urlProvider: mockProvider)

        async let r1 = service.imageRequest(bucket: "b", storagePath: "same.jpg")
        async let r2 = service.imageRequest(bucket: "b", storagePath: "same.jpg")
        async let r3 = service.imageRequest(bucket: "b", storagePath: "same.jpg")

        let _ = try await [r1, r2, r3]

        XCTAssertEqual(mockProvider.callCount, 1, "Expected only one signed URL fetch for concurrent requests to same path")
    }

    func testImageRequestPropagatesSignedURLError() async {
        let expectedError = NSError(domain: "test", code: 42)
        mockProvider.errorToThrow = expectedError
        let service = ImageCacheService(urlProvider: mockProvider)

        do {
            _ = try await service.imageRequest(bucket: "bucket", storagePath: "path.jpg")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, 42)
        }
    }

    func testRetrySucceedsAfterTransientError() async throws {
        mockProvider.errorToThrow = NSError(domain: "test", code: 1)
        let service = ImageCacheService(urlProvider: mockProvider)

        do {
            _ = try await service.imageRequest(bucket: "b", storagePath: "file.jpg")
            XCTFail("Expected first call to fail")
        } catch {}

        mockProvider.errorToThrow = nil
        let request = try await service.imageRequest(bucket: "b", storagePath: "file.jpg")
        let cacheKey = request.userInfo[.imageIdKey] as? String
        XCTAssertEqual(cacheKey, "b/file.jpg")
    }

    func testPipelineHasConfiguredCacheLimits() {
        let diskLimit = 200 * 1024 * 1024
        let memoryLimit = 100 * 1024 * 1024
        let service = ImageCacheService(
            urlProvider: mockProvider,
            diskCacheSizeLimit: diskLimit,
            memoryCacheSizeLimit: memoryLimit
        )

        let dataCache = service.pipeline.configuration.dataCache as? DataCache
        XCTAssertNotNil(dataCache, "Expected disk cache to be configured")
        XCTAssertEqual(dataCache?.sizeLimit, diskLimit)

        let imageCache = service.pipeline.configuration.imageCache as? ImageCache
        XCTAssertNotNil(imageCache, "Expected memory cache to be configured")
        XCTAssertEqual(imageCache?.costLimit, memoryLimit)
    }
}
