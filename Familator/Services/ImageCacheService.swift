import Foundation
import Nuke
import OSLog

private let logger = Logger(subsystem: "com.familator", category: "ImageCache")

actor ImageCacheService {
    static let shared = ImageCacheService()

    nonisolated let pipeline: ImagePipeline

    private let urlProvider: SignedURLProviding
    private let signedURLExpiresIn: Int
    private var inFlightURLRequests: [String: Task<URL, Error>] = [:]

    init(
        urlProvider: SignedURLProviding = SupabaseSignedURLProvider(),
        diskCacheSizeLimit: Int = 200 * 1024 * 1024,
        memoryCacheSizeLimit: Int = 100 * 1024 * 1024,
        signedURLExpiresIn: Int = 300
    ) {
        self.urlProvider = urlProvider
        self.signedURLExpiresIn = signedURLExpiresIn

        var dataCache: DataCache?
        do {
            dataCache = try DataCache(name: "com.familator.imageCache")
            dataCache?.sizeLimit = diskCacheSizeLimit
        } catch {
            logger.error("Failed to create disk cache: \(error.localizedDescription)")
        }

        let imageCache = ImageCache()
        imageCache.costLimit = memoryCacheSizeLimit

        var config = ImagePipeline.Configuration()
        config.dataCache = dataCache
        config.imageCache = imageCache
        self.pipeline = ImagePipeline(configuration: config)
    }

    func imageRequest(bucket: String, storagePath: String) async throws -> ImageRequest {
        let signedURL = try await fetchOrCoalesceSignedURL(bucket: bucket, path: storagePath)
        var request = ImageRequest(url: signedURL)
        request.userInfo[.imageIdKey] = "\(bucket)/\(storagePath)"
        return request
    }

    private func fetchOrCoalesceSignedURL(bucket: String, path: String) async throws -> URL {
        let key = "\(bucket)/\(path)"

        if let existing = inFlightURLRequests[key] {
            return try await existing.value
        }

        let urlProvider = self.urlProvider
        let expiresIn = self.signedURLExpiresIn
        let task = Task {
            try await urlProvider.signedURL(bucket: bucket, path: path, expiresIn: expiresIn)
        }
        inFlightURLRequests[key] = task

        do {
            let url = try await task.value
            inFlightURLRequests[key] = nil
            return url
        } catch {
            inFlightURLRequests[key] = nil
            throw error
        }
    }
}
