import Foundation
import SwiftUI

@MainActor
final class TripPlacesViewModel: ObservableObject {
    let tripId: Int64

    @Published var places: [TripPlace] = []
    @Published var legs: [TripLeg] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    // Autocomplete state
    @Published var searchQuery = ""
    @Published var suggestions: [PlaceSuggestion] = []
    @Published var isSearching = false

    private var loadSequence = 0
    private var initialLoadAttemptCompleted = false
    private let placesService = TripPlacesService()
    private let legsService = TripLegsService()
    private let googleService = GooglePlacesService()

    var isGoogleSearchAvailable: Bool { googleService.isAvailable }

    func legName(for legId: Int64?) -> String? {
        guard let legId else { return nil }
        return legs.first(where: { $0.id == legId })?.name
    }

    init(tripId: Int64) {
        self.tripId = tripId
    }

    // MARK: - Load

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
            async let fetchedPlaces = placesService.fetchPlaces(tripId: tripId)
            async let fetchedLegs = legsService.fetchLegs(tripId: tripId)
            let (placesResult, legsResult) = try await (fetchedPlaces, fetchedLegs)
            guard sequence == loadSequence else { return }
            places = placesResult
            legs = legsResult
        } catch {
            guard sequence == loadSequence else { return }
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Search

    func searchPlaces(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            suggestions = try await googleService.autocomplete(query: trimmed)
        } catch {
            if !(error is CancellationError) {
                suggestions = []
            }
        }
    }

    // MARK: - Add

    func addPlace(from suggestion: PlaceSuggestion) async {
        do {
            let details = try await googleService.fetchDetails(placeId: suggestion.id)
            let nextOrder = (places.map(\.sortOrder).max() ?? -1) + 1
            let payload = TripPlaceInsert(
                tripId: tripId,
                name: details?.name ?? suggestion.displayName,
                lat: details?.lat,
                lng: details?.lng,
                googlePlaceId: details?.googlePlaceId ?? suggestion.id,
                sortOrder: nextOrder
            )
            let place = try await placesService.createPlace(payload: payload)
            places.append(place)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addPlaceByName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let nextOrder = (places.map(\.sortOrder).max() ?? -1) + 1
            let payload = TripPlaceInsert(
                tripId: tripId,
                name: trimmed,
                lat: nil,
                lng: nil,
                googlePlaceId: nil,
                sortOrder: nextOrder
            )
            let place = try await placesService.createPlace(payload: payload)
            places.append(place)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Update

    func updateRating(placeId: Int64, rating: Int?) async {
        guard let index = places.firstIndex(where: { $0.id == placeId }) else { return }
        let oldRating = places[index].rating
        places[index].rating = rating

        do {
            if let rating {
                try await placesService.updatePlace(id: placeId, update: TripPlaceUpdate(rating: rating))
            } else {
                try await placesService.updatePlace(id: placeId, update: TripPlaceUpdate(clearRating: true))
            }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            places[index].rating = oldRating
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    func updatePlace(id: Int64, update: TripPlaceUpdate) async {
        do {
            try await placesService.updatePlace(id: id, update: update)
            await load()
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Delete

    func deletePlace(id: Int64) async {
        let snapshot = places
        places.removeAll { $0.id == id }

        do {
            try await placesService.deletePlace(id: id)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            places = snapshot
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Reorder

    func movePlace(from source: IndexSet, to destination: Int) async {
        let snapshot = places
        places.move(fromOffsets: source, toOffset: destination)

        let orderedIds = places.map(\.id)
        do {
            let reordered = try await placesService.reorderPlaces(tripId: tripId, placeIds: orderedIds)
            places = reordered
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            places = snapshot
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }
}
