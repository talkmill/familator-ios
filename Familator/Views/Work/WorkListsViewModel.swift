import Foundation
import SwiftUI

@MainActor
final class WorkListsViewModel: ObservableObject {
    @Published var lists: [FamilatorList] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false

    private var cachedUserId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    private let listsService = ListsService()

    func reset() {
        lists = []
        cachedUserId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        isBlockingLoad = false
        isRefreshing = false
    }

    func appendList(_ list: FamilatorList) {
        lists.append(list)
    }

    func load(workspaceId: String?, userId: UUID?) async {
        guard let userId, let workspaceId else {
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
            let fetched = try await listsService.fetchLists(workspaceId: workspaceId, userId: userId)
            guard sequence == loadSequence else { return }
            lists = fetched
            cachedUserId = userKey
        } catch {
            guard sequence == loadSequence else { return }
        }
    }
}
