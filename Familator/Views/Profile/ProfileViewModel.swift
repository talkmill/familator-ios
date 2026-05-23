import Foundation
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private var cachedUserId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    private let profileService = ProfileService()

    func reset() {
        profile = nil
        errorMessage = nil
        cachedUserId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        isBlockingLoad = false
        isRefreshing = false
    }

    func load(userId: UUID?) async {
        guard let userId else {
            reset()
            return
        }

        let userKey = userId.uuidString.lowercased()
        if let cached = cachedUserId, cached != userKey {
            reset()
        }

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
            let p = try await profileService.fetchProfile(userId: userId)
            guard sequence == loadSequence else { return }
            profile = p
            cachedUserId = userKey
        } catch {
            guard sequence == loadSequence else { return }
            errorMessage = error.localizedDescription
        }
    }
}
