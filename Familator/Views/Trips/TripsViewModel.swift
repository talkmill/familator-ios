import Foundation
import SwiftUI

@MainActor
final class TripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var mutationError: String?

    private var cachedWorkspaceId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    private let tripService: TripServiceProtocol

    init(tripService: TripServiceProtocol = TripService()) {
        self.tripService = tripService
    }

    func reset() {
        trips = []
        errorMessage = nil
        mutationError = nil
        cachedWorkspaceId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        isBlockingLoad = false
        isRefreshing = false
    }

    func load(workspaceId: String?) async {
        guard let workspaceId else {
            reset()
            return
        }

        if let cached = cachedWorkspaceId, cached != workspaceId {
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
            let fetched = try await tripService.fetchTrips(workspaceId: workspaceId)
            guard sequence == loadSequence else { return }
            trips = sortedTrips(fetched)
            cachedWorkspaceId = workspaceId
            errorMessage = nil
        } catch {
            guard sequence == loadSequence else { return }
            errorMessage = error.localizedDescription
        }
    }

    func appendTrip(_ trip: Trip) {
        trips = sortedTrips(trips + [trip])
    }

    func deleteTrip(_ trip: Trip) async {
        mutationError = nil
        do {
            try await tripService.deleteTrip(trip)
            trips.removeAll { $0.id == trip.id }
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func sortedTrips(_ trips: [Trip]) -> [Trip] {
        trips.sorted { a, b in
            let statusA = a.status.sortOrder
            let statusB = b.status.sortOrder
            if statusA != statusB { return statusA < statusB }
            // Within same status, sort by start_date ascending (nil last)
            switch (a.startDate, b.startDate) {
            case (nil, nil): return a.createdAt > b.createdAt
            case (nil, _): return false
            case (_, nil): return true
            case (let sa?, let sb?): return sa < sb
            }
        }
    }
}
