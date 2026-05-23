import Foundation

enum RouteOptimizer {
    static func haversineKm(_ a: (lat: Double, lng: Double), _ b: (lat: Double, lng: Double)) -> Double {
        let R = 6371.0
        let phi1 = a.lat * .pi / 180
        let phi2 = b.lat * .pi / 180
        let dPhi = (b.lat - a.lat) * .pi / 180
        let dLambda = (b.lng - a.lng) * .pi / 180
        let h = sin(dPhi / 2) * sin(dPhi / 2)
            + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * R * asin(sqrt(h))
    }

    static func totalDistance(_ route: [TripPlace]) -> Double {
        guard route.count >= 2 else { return 0 }
        var dist = 0.0
        for i in 0 ..< (route.count - 1) {
            guard let a = coordTuple(route[i]), let b = coordTuple(route[i + 1]) else { continue }
            dist += haversineKm(a, b)
        }
        return dist
    }

    static func optimizeRoute(_ places: [TripPlace]) -> [TripPlace] {
        guard places.count > 1 else { return places }

        let anchorStart: TripPlace? = places.first?.isRouteAnchor == true ? places.first : nil
        let lastPlace = places.last!
        let anchorEnd: TripPlace? =
            lastPlace.isRouteAnchor && places.count > 1 && lastPlace.id != places.first!.id
            ? lastPlace : nil

        let middleStart = anchorStart != nil ? 1 : 0
        let middleEnd = anchorEnd != nil ? places.count - 1 : places.count
        let middle = Array(places[middleStart ..< middleEnd])

        guard middle.count > 1 else {
            return (anchorStart.map { [$0] } ?? []) + middle + (anchorEnd.map { [$0] } ?? [])
        }

        var geo: [(place: TripPlace, originalIndex: Int)] = []
        var noCoord: [(place: TripPlace, originalIndex: Int)] = []

        for (i, p) in middle.enumerated() {
            if p.lat != nil && p.lng != nil {
                geo.append((place: p, originalIndex: i))
            } else {
                noCoord.append((place: p, originalIndex: i))
            }
        }

        let optimizedGeo: [TripPlace]
        if geo.count <= 1 {
            optimizedGeo = geo.map(\.place)
        } else {
            let afterNN = nearestNeighbour(geo.map(\.place))
            optimizedGeo = twoOpt(afterNN)
        }

        var geoQueue = optimizedGeo
        var noCoordByIndex: [Int: TripPlace] = [:]
        for item in noCoord {
            noCoordByIndex[item.originalIndex] = item.place
        }

        var reassembled: [TripPlace] = []
        for i in 0 ..< middle.count {
            if let nc = noCoordByIndex[i] {
                reassembled.append(nc)
            } else {
                reassembled.append(geoQueue.removeFirst())
            }
        }

        return (anchorStart.map { [$0] } ?? []) + reassembled + (anchorEnd.map { [$0] } ?? [])
    }

    private static func coordTuple(_ place: TripPlace) -> (lat: Double, lng: Double)? {
        guard let lat = place.lat, let lng = place.lng else { return nil }
        return (lat: lat, lng: lng)
    }

    private static func haversineKm(_ a: TripPlace, _ b: TripPlace) -> Double {
        guard let ca = coordTuple(a), let cb = coordTuple(b) else { return 0 }
        return haversineKm(ca, cb)
    }

    private static func nearestNeighbour(_ places: [TripPlace]) -> [TripPlace] {
        guard places.count > 1 else { return places }

        var remaining = Set(places.indices)
        var ordered: [TripPlace] = []
        var current = 0
        remaining.remove(0)
        ordered.append(places[0])

        while !remaining.isEmpty {
            var bestIdx = -1
            var bestDist = Double.infinity
            for idx in remaining {
                let d = haversineKm(places[current], places[idx])
                if d < bestDist || (d == bestDist && idx < bestIdx) {
                    bestDist = d
                    bestIdx = idx
                }
            }
            remaining.remove(bestIdx)
            ordered.append(places[bestIdx])
            current = bestIdx
        }

        return ordered
    }

    private static func twoOpt(_ route: [TripPlace]) -> [TripPlace] {
        let n = route.count
        guard n > 2 else { return route }

        var ordered = route
        var improved = true

        while improved {
            improved = false
            for i in 0 ..< (n - 1) {
                for j in (i + 1) ..< n {
                    let before =
                        (i > 0 ? haversineKm(ordered[i - 1], ordered[j]) : 0)
                        + (j < n - 1 ? haversineKm(ordered[i], ordered[j + 1]) : 0)
                    let current =
                        (i > 0 ? haversineKm(ordered[i - 1], ordered[i]) : 0)
                        + (j < n - 1 ? haversineKm(ordered[j], ordered[j + 1]) : 0)
                    if before - current < -1e-9 {
                        var lo = i
                        var hi = j
                        while lo < hi {
                            ordered.swapAt(lo, hi)
                            lo += 1
                            hi -= 1
                        }
                        improved = true
                    }
                }
            }
        }

        return ordered
    }
}
