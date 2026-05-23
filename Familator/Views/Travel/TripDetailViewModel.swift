import Foundation

@MainActor
final class TripDetailViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var activeTab: TripTab = .checklist
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    @Published var destinationDraft: String = ""
    @Published var isEditingDestination = false
    @Published var localStartDate: String?
    @Published var localEndDate: String?
    @Published var localTransportMode: TransportMode = .driving

    private let service = TripService()
    private var tripId: Int64?

    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var status: TripStatus {
        let today = Self.todayFormatter.string(from: Date())
        return TripStatus.compute(startDate: localStartDate, endDate: localEndDate, today: today)
    }

    var nights: Int? {
        computeNights(startDate: localStartDate, endDate: localEndDate)
    }

    var dateRange: String {
        formatTripDateRange(startDate: localStartDate, endDate: localEndDate)
    }

    func load(tripId: Int64) async {
        self.tripId = tripId
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await service.fetchTrip(id: tripId)
            trip = fetched
            if let fetched {
                destinationDraft = fetched.destination
                localStartDate = fetched.startDate
                localEndDate = fetched.endDate
                localTransportMode = fetched.transportMode ?? .driving
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func saveDestination() async {
        guard let tripId else { return }
        let trimmed = destinationDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            destinationDraft = trip?.destination ?? ""
            return
        }
        isSaving = true
        do {
            try await service.updateTripDestination(id: tripId, destination: trimmed)
            trip?.destination = trimmed
            destinationDraft = trimmed
        } catch {
            errorMessage = error.localizedDescription
            destinationDraft = trip?.destination ?? ""
        }
        isSaving = false
        isEditingDestination = false
    }

    func saveStartDate(_ dateString: String?) async {
        guard let tripId else { return }
        localStartDate = dateString
        isSaving = true
        do {
            try await service.updateTripStartDate(id: tripId, startDate: dateString)
            trip?.startDate = dateString
        } catch {
            errorMessage = error.localizedDescription
            localStartDate = trip?.startDate
        }
        isSaving = false
    }

    func saveEndDate(_ dateString: String?) async {
        guard let tripId else { return }
        localEndDate = dateString
        isSaving = true
        do {
            try await service.updateTripEndDate(id: tripId, endDate: dateString)
            trip?.endDate = dateString
        } catch {
            errorMessage = error.localizedDescription
            localEndDate = trip?.endDate
        }
        isSaving = false
    }

    func saveTransportMode(_ mode: TransportMode) async {
        guard let tripId else { return }
        localTransportMode = mode
        isSaving = true
        do {
            try await service.updateTripTransportMode(id: tripId, transportMode: mode)
            trip?.transportMode = mode
        } catch {
            errorMessage = error.localizedDescription
            localTransportMode = trip?.transportMode ?? .driving
        }
        isSaving = false
    }
}
