import Foundation

@MainActor
final class TripLegsViewModel: ObservableObject {
    let tripId: Int64

    @Published var legs: [TripLeg] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private var loadSequence = 0
    private var initialLoadAttemptCompleted = false
    private let legsService: TripLegsServiceProtocol

    init(tripId: Int64, legsService: TripLegsServiceProtocol = TripLegsService()) {
        self.tripId = tripId
        self.legsService = legsService
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
            let fetched = try await legsService.fetchLegs(tripId: tripId)
            guard sequence == loadSequence else { return }
            legs = fetched
        } catch {
            guard sequence == loadSequence else { return }
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Create

    func addLeg(name: String, transportMode: TransportMode = .driving) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let nextOrder = (legs.map(\.sortOrder).max() ?? -1) + 1
            let payload = TripLegInsert(
                tripId: tripId,
                name: trimmed,
                sortOrder: nextOrder,
                transportMode: transportMode
            )
            let leg = try await legsService.createLeg(payload: payload)
            legs.append(leg)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Update

    /// Updates a leg's name and/or transport mode in a single request.
    /// Returns `true` on success, `false` on failure.
    func updateLeg(id: Int64, name: String? = nil, transportMode: TransportMode? = nil) async -> Bool {
        guard let index = legs.firstIndex(where: { $0.id == id }) else { return false }

        let oldName = legs[index].name
        let oldMode = legs[index].transportMode

        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            legs[index].name = trimmed
        }
        if let transportMode {
            legs[index].transportMode = transportMode
        }

        do {
            let update = TripLegUpdate(
                name: name?.trimmingCharacters(in: .whitespacesAndNewlines),
                transportMode: transportMode
            )
            try await legsService.updateLeg(id: id, update: update)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
            return true
        } catch {
            legs[index].name = oldName
            legs[index].transportMode = oldMode
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Delete

    func deleteLeg(id: Int64) async {
        let snapshot = legs
        legs.removeAll { $0.id == id }

        do {
            try await legsService.deleteLeg(id: id)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            legs = snapshot
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Reorder

    func moveLeg(from source: IndexSet, to destination: Int) async {
        let snapshot = legs
        legs.move(fromOffsets: source, toOffset: destination)

        let orderedIds = legs.map(\.id)
        do {
            let reordered = try await legsService.reorderLegs(tripId: tripId, legIds: orderedIds)
            legs = reordered
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            legs = snapshot
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }
}
