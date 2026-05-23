import Foundation
import CoreLocation

struct RouteResult {
    let distanceKm: Double
    let durationMin: Int
    let polylineCoords: [CLLocationCoordinate2D]
    let legs: [RouteLegResult]
}

struct RouteLegResult {
    let distanceKm: Double
    let durationMin: Int
}

struct MultiLegRouteResult {
    let polylineCoords: [CLLocationCoordinate2D]
    let totalDistanceKm: Double
    let totalDurationMin: Int
    let legs: [LegRouteResult]
}

struct LegRouteResult {
    let polylineCoords: [CLLocationCoordinate2D]
    let distanceKm: Double
    let durationMin: Int
    let mode: TransportMode
}

struct LegGroup {
    let mode: TransportMode
    let coords: [CLLocationCoordinate2D]
}

final class OSRMService {
    static let shared = OSRMService()

    private let baseURL = "https://router.project-osrm.org/route/v1"
    private let session: URLSession

    private let modeSpeedKmh: [TransportMode: Double?] = [
        .driving: nil,
        .walking: 5,
        .cycling: 15,
    ]

    private init(session: URLSession = .shared) {
        self.session = session
    }

    /// Test-only initializer with a custom session.
    static func forTesting(session: URLSession) -> OSRMService {
        OSRMService(session: session)
    }

    func fetchRoute(
        coords: [CLLocationCoordinate2D],
        mode: TransportMode = .driving
    ) async throws -> RouteResult {
        guard coords.count >= 2 else {
            throw OSRMError.insufficientCoordinates
        }

        let coordStr = coords.map { "\($0.longitude),\($0.latitude)" }.joined(separator: ";")
        let urlString = "\(baseURL)/\(mode.osrmProfile)/\(coordStr)?overview=full&geometries=geojson"

        guard let url = URL(string: urlString) else {
            throw OSRMError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OSRMError.httpError
        }

        let osrmResponse = try JSONDecoder().decode(OSRMResponse.self, from: data)

        guard osrmResponse.code == "Ok" else {
            throw OSRMError.osrmError(code: osrmResponse.code)
        }

        guard let route = osrmResponse.routes?.first else {
            throw OSRMError.noRoutes
        }

        let polylineCoords = route.geometry.coordinates.compactMap { coord -> CLLocationCoordinate2D? in
            guard coord.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }

        let legs = (route.legs ?? []).map { leg in
            RouteLegResult(
                distanceKm: (leg.distance / 1000 * 10).rounded() / 10,
                durationMin: durationMinutes(distanceMeters: leg.distance, durationSeconds: leg.duration, mode: mode)
            )
        }

        return RouteResult(
            distanceKm: (route.distance / 1000 * 10).rounded() / 10,
            durationMin: durationMinutes(distanceMeters: route.distance, durationSeconds: route.duration, mode: mode),
            polylineCoords: polylineCoords,
            legs: legs
        )
    }

    func fetchMultiLegRoute(legGroups: [LegGroup]) async throws -> MultiLegRouteResult {
        guard !legGroups.isEmpty else {
            return MultiLegRouteResult(polylineCoords: [], totalDistanceKm: 0, totalDurationMin: 0, legs: [])
        }

        // Build effective coord lists with prepended join points.
        var effectiveCoords: [[CLLocationCoordinate2D]] = []
        for i in 0..<legGroups.count {
            let group = legGroups[i]
            if i == 0 {
                effectiveCoords.append(group.coords)
            } else {
                let prevEffective = effectiveCoords[i - 1]
                if let lastCoord = prevEffective.last {
                    effectiveCoords.append([lastCoord] + group.coords)
                } else {
                    effectiveCoords.append(group.coords)
                }
            }
        }

        // Fetch routes in parallel.
        let results: [RouteResult?] = await withTaskGroup(of: (Int, RouteResult?).self) { group in
            for (i, legGroup) in legGroups.enumerated() {
                let coords = effectiveCoords[i]
                group.addTask {
                    guard coords.count >= 2 else { return (i, nil) }
                    return (i, try? await self.fetchRoute(coords: coords, mode: legGroup.mode))
                }
            }

            var indexed: [(Int, RouteResult?)] = []
            for await result in group {
                indexed.append(result)
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }

        var totalDistanceKm: Double = 0
        var totalDurationMin = 0
        var polylineCoords: [CLLocationCoordinate2D] = []
        var legs: [LegRouteResult] = []

        for (i, result) in results.enumerated() {
            let group = legGroups[i]

            guard let result else {
                legs.append(LegRouteResult(polylineCoords: [], distanceKm: 0, durationMin: 0, mode: group.mode))
                continue
            }

            totalDistanceKm += result.distanceKm
            totalDurationMin += result.durationMin
            legs.append(LegRouteResult(
                polylineCoords: result.polylineCoords,
                distanceKm: result.distanceKm,
                durationMin: result.durationMin,
                mode: group.mode
            ))

            // Append polyline, avoiding duplicate join point.
            if polylineCoords.isEmpty {
                polylineCoords.append(contentsOf: result.polylineCoords)
            } else {
                polylineCoords.append(contentsOf: result.polylineCoords.dropFirst())
            }
        }

        return MultiLegRouteResult(
            polylineCoords: polylineCoords,
            totalDistanceKm: (totalDistanceKm * 10).rounded() / 10,
            totalDurationMin: totalDurationMin,
            legs: legs
        )
    }

    private func durationMinutes(distanceMeters: Double, durationSeconds: Double, mode: TransportMode) -> Int {
        if let speedKmh = modeSpeedKmh[mode], let speed = speedKmh {
            return max(1, Int((distanceMeters / 1000 / speed * 60).rounded()))
        }
        return Int((durationSeconds / 60).rounded())
    }
}

enum OSRMError: LocalizedError {
    case insufficientCoordinates
    case invalidURL
    case httpError
    case osrmError(code: String)
    case noRoutes

    var errorDescription: String? {
        switch self {
        case .insufficientCoordinates: return "At least 2 coordinates required"
        case .invalidURL: return "Invalid route URL"
        case .httpError: return "Route server error"
        case .osrmError(let code): return "Route error: \(code)"
        case .noRoutes: return "No routes found"
        }
    }
}

// MARK: - OSRM Response Types

private struct OSRMResponse: Decodable {
    let code: String
    let routes: [OSRMRoute]?
}

private struct OSRMRoute: Decodable {
    let distance: Double
    let duration: Double
    let geometry: OSRMGeometry
    let legs: [OSRMLeg]?
}

private struct OSRMGeometry: Decodable {
    let coordinates: [[Double]]
}

private struct OSRMLeg: Decodable {
    let distance: Double
    let duration: Double
}
