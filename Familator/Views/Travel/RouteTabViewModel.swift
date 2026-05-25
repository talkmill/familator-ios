import CoreLocation
import Foundation
import MapKit

@MainActor
final class RouteTabViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var legs: [TripLeg] = []
    @Published var places: [TripPlace] = []
    @Published var routeResult: MultiLegRouteResult?
    @Published var transportMode: TransportMode = .driving
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPlaceId: Int64?
    @Published var isOptimizing = false
    var showToast: ((ToastVariant, String) -> Void)?

    private let tripService: TripServiceProtocol
    private let legsService: TripLegsServiceProtocol
    private let placesService: TripPlacesServiceProtocol
    private let osrmService = OSRMService.shared

    private var loadSequence = 0

    init(
        tripService: TripServiceProtocol = TripService(),
        legsService: TripLegsServiceProtocol = TripLegsService(),
        placesService: TripPlacesServiceProtocol = TripPlacesService()
    ) {
        self.tripService = tripService
        self.legsService = legsService
        self.placesService = placesService
    }

    var geocodedPlaces: [TripPlace] {
        places.filter { $0.coordinate != nil }
    }

    var orderedPlaces: [TripPlace] {
        let grouped = RouteGrouping.groupPlacesByLeg(legs: legs, places: places)
        return RouteGrouping.flattenGroupedPlaces(legs: legs, grouped: grouped)
    }

    var orderedGeocodedPlaces: [TripPlace] {
        orderedPlaces.filter { $0.coordinate != nil }
    }

    var canOptimize: Bool {
        let all = orderedPlaces
        guard all.count >= 2 else { return false }
        let isStart = all.first?.isRouteAnchor == true
        let isEnd = all.count > 1 && all.last?.isRouteAnchor == true
        let middleStart = isStart ? 1 : 0
        let middleEnd = isEnd ? all.count - 1 : all.count
        let middle = Array(all[middleStart ..< middleEnd])
        let geoCount = middle.filter { $0.coordinate != nil }.count
        return geoCount >= 2
    }

    func load(tripId: Int64) async {
        loadSequence &+= 1
        let seq = loadSequence
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedLegs = legsService.fetchLegs(tripId: tripId)
            async let fetchedPlaces = placesService.fetchPlaces(tripId: tripId)

            let (newLegs, newPlaces) = try await (fetchedLegs, fetchedPlaces)

            guard seq == loadSequence else { return }
            legs = newLegs
            places = newPlaces

            await fetchRoute()
        } catch {
            guard seq == loadSequence else { return }
            if let msg = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = msg
            }
        }

        guard seq == loadSequence else { return }
        isLoading = false
    }

    func setTrip(_ trip: Trip) {
        self.trip = trip
        self.transportMode = trip.transportMode ?? .driving
    }

    func fetchRoute() async {
        guard let trip else { return }

        var routeTrip = trip
        routeTrip.transportMode = transportMode

        let legGroups = RouteGrouping.buildLegGroups(trip: routeTrip, legs: legs, places: places)

        guard !legGroups.isEmpty else {
            routeResult = nil
            return
        }

        let totalCoords = legGroups.reduce(0) { $0 + $1.coords.count }
        guard totalCoords >= 2 else {
            routeResult = nil
            return
        }

        do {
            let result = try await osrmService.fetchMultiLegRoute(legGroups: legGroups)
            routeResult = result
        } catch {
            routeResult = nil
        }
    }

    func changeTransportMode(to mode: TransportMode) async {
        guard let trip else { return }
        let oldMode = transportMode
        transportMode = mode

        do {
            try await tripService.updateTripTransportMode(id: trip.id, transportMode: mode)
            await fetchRoute()
        } catch {
            transportMode = oldMode
            if let msg = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = msg
            }
        }
    }

    func changeLegTransportMode(legId: Int64, to mode: TransportMode) async {
        guard let index = legs.firstIndex(where: { $0.id == legId }) else { return }
        let oldMode = legs[index].transportMode
        legs[index].transportMode = mode

        do {
            try await legsService.updateLeg(id: legId, update: TripLegUpdate(transportMode: mode))
            await fetchRoute()
        } catch {
            legs[index].transportMode = oldMode
            if let msg = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = msg
            }
        }
    }

    func optimizeRoute() async {
        guard let trip else { return }
        guard canOptimize else { return }
        isOptimizing = true
        defer { isOptimizing = false }
        let optimized = RouteOptimizer.optimizeRoute(orderedPlaces)
        let newIds = optimized.map(\.id)
        do {
            let updated = try await placesService.reorderPlaces(tripId: trip.id, placeIds: newIds)
            places = updated
            await fetchRoute()
            showToast?(.success, "Route optimized")
        } catch {
            if let msg = UserFacingAsyncError.alertMessage(from: error) {
                showToast?(.error, msg)
            } else {
                showToast?(.error, "Failed to optimize route")
            }
        }
    }

    func toggleAnchor(placeId: Int64) async {
        guard let index = places.firstIndex(where: { $0.id == placeId }) else { return }
        let current = places[index].isRouteAnchor
        places[index].isRouteAnchor = !current
        do {
            try await placesService.updatePlace(id: placeId, update: TripPlaceUpdate(isRouteAnchor: !current))
        } catch {
            places[index].isRouteAnchor = current
            if let msg = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = msg
            }
        }
    }

    func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(mins) min"
    }

    func formatDistance(_ km: Double) -> String {
        if km < 1 {
            return "\(Int(km * 1000)) m"
        }
        return String(format: "%.1f km", km)
    }
}
