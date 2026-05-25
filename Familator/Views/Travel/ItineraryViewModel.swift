import Foundation

@MainActor
final class ItineraryViewModel: ObservableObject {
    let tripId: Int64
    let workspaceId: String
    let ownerId: UUID

    @Published var items: [TripItineraryItem] = []
    @Published var legs: [TripLeg] = []
    @Published var places: [TripPlace] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private var loadSequence = 0
    private var initialLoadAttemptCompleted = false
    private let itineraryService: TripItineraryServiceProtocol
    private let legsService: TripLegsServiceProtocol
    private let placesService: TripPlacesServiceProtocol

    init(
        tripId: Int64,
        workspaceId: String,
        ownerId: UUID,
        itineraryService: TripItineraryServiceProtocol = TripItineraryService(),
        legsService: TripLegsServiceProtocol = TripLegsService(),
        placesService: TripPlacesServiceProtocol = TripPlacesService()
    ) {
        self.tripId = tripId
        self.workspaceId = workspaceId
        self.ownerId = ownerId
        self.itineraryService = itineraryService
        self.legsService = legsService
        self.placesService = placesService
    }

    struct ItemGroup: Identifiable {
        let leg: TripLeg?
        let items: [TripItineraryItem]
        var id: Int64 { leg?.id ?? -1 }
    }

    var groupedItems: [ItemGroup] {
        if legs.isEmpty {
            return [ItemGroup(leg: nil, items: items)]
        }
        let grouped = Dictionary(grouping: items) { $0.legId }
        var result: [ItemGroup] = []
        for leg in legs {
            if let legItems = grouped[leg.id], !legItems.isEmpty {
                result.append(ItemGroup(leg: leg, items: legItems))
            }
        }
        if let unassigned = grouped[nil], !unassigned.isEmpty {
            result.append(ItemGroup(leg: nil, items: unassigned))
        }
        return result
    }

    func legName(for legId: Int64?) -> String? {
        guard let legId else { return nil }
        return legs.first(where: { $0.id == legId })?.name
    }

    func placeName(for placeId: Int64?) -> String? {
        guard let placeId else { return nil }
        return places.first(where: { $0.id == placeId })?.name
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
            async let fetchedItems = itineraryService.fetchItems(tripId: tripId)
            async let fetchedLegs = legsService.fetchLegs(tripId: tripId)
            async let fetchedPlaces = placesService.fetchPlaces(tripId: tripId)
            let (itemsResult, legsResult, placesResult) = try await (fetchedItems, fetchedLegs, fetchedPlaces)
            guard sequence == loadSequence else { return }
            items = itemsResult
            legs = legsResult
            places = placesResult
        } catch {
            guard sequence == loadSequence else { return }
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Create

    func addItem(
        itemType: ItineraryItemType,
        title: String,
        description: String? = nil,
        date: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        confirmationNumber: String? = nil,
        provider: String? = nil,
        legId: Int64? = nil,
        placeId: Int64? = nil
    ) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let wsUUID = UUID(uuidString: workspaceId) else {
            errorMessage = "Invalid workspace ID"
            return
        }

        do {
            let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
            var payload = TripItineraryItemInsert(
                tripId: tripId,
                workspaceId: wsUUID,
                ownerId: ownerId,
                itemType: itemType,
                title: trimmed,
                sortOrder: nextOrder
            )
            payload.description = description
            payload.date = date
            payload.startTime = startTime
            payload.endTime = endTime
            payload.confirmationNumber = confirmationNumber
            payload.provider = provider
            payload.legId = legId
            payload.placeId = placeId

            _ = try await itineraryService.createItem(payload: payload)
            await load()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Update

    func updateItem(id: Int64, update: TripItineraryItemUpdate) async {
        do {
            try await itineraryService.updateItem(id: id, update: update)
            await load()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Delete

    func deleteItem(id: Int64) async {
        let snapshot = items
        items.removeAll { $0.id == id }

        do {
            try await itineraryService.deleteItem(id: id)
        } catch {
            items = snapshot
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Reorder

    func moveItem(from source: IndexSet, to destination: Int, sectionItems: [TripItineraryItem]) async {
        var reordered = sectionItems
        reordered.move(fromOffsets: source, toOffset: destination)

        let snapshot = items
        let sectionIds = Set(sectionItems.map(\.id))
        var updated: [TripItineraryItem] = []
        var iter = reordered.makeIterator()
        for item in items {
            if sectionIds.contains(item.id) {
                if let next = iter.next() { updated.append(next) }
            } else {
                updated.append(item)
            }
        }
        items = updated

        let orderedIds = items.map(\.id)
        do {
            let result = try await itineraryService.reorderItems(tripId: tripId, itemIds: orderedIds)
            items = result
        } catch {
            items = snapshot
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }
}
