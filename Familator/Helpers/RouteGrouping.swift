import CoreLocation
import Foundation

struct GroupedPlaces {
    let byLegId: [Int64: [TripPlace]]
    let ungrouped: [TripPlace]
}

enum RouteGrouping {
    /// Groups places by leg, sorted by leg sort_order then place sort_order.
    /// Places with a leg_id pointing to a non-existent leg are treated as ungrouped.
    static func groupPlacesByLeg(legs: [TripLeg], places: [TripPlace]) -> GroupedPlaces {
        let legIds = Set(legs.map(\.id))

        var byLegId: [Int64: [TripPlace]] = [:]
        for leg in legs {
            byLegId[leg.id] = []
        }
        var ungrouped: [TripPlace] = []

        for place in places {
            if let legId = place.legId, legIds.contains(legId) {
                byLegId[legId, default: []].append(place)
            } else {
                ungrouped.append(place)
            }
        }

        // Sort each leg's places by sort_order, then created_at as tiebreaker.
        for legId in byLegId.keys {
            byLegId[legId]?.sort { a, b in
                if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
                return a.createdAt < b.createdAt
            }
        }

        ungrouped.sort { a, b in
            if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
            return a.createdAt < b.createdAt
        }

        return GroupedPlaces(byLegId: byLegId, ungrouped: ungrouped)
    }

    /// Returns all places in visual order: legs sorted by sort_order, then ungrouped.
    static func flattenGroupedPlaces(legs: [TripLeg], grouped: GroupedPlaces) -> [TripPlace] {
        let sortedLegs = legs.sorted { $0.sortOrder < $1.sortOrder }
        var result: [TripPlace] = []

        for leg in sortedLegs {
            if let group = grouped.byLegId[leg.id] {
                result.append(contentsOf: group)
            }
        }

        result.append(contentsOf: grouped.ungrouped)
        return result
    }

    /// Builds leg groups for OSRM multi-leg routing.
    static func buildLegGroups(
        trip: Trip,
        legs: [TripLeg],
        places: [TripPlace]
    ) -> [LegGroup] {
        let grouped = groupPlacesByLeg(legs: legs, places: places)

        var legGroups: [LegGroup] = []
        let sortedLegs = legs.sorted { $0.sortOrder < $1.sortOrder }

        for leg in sortedLegs {
            let legPlaces = grouped.byLegId[leg.id] ?? []
            let coords = legPlaces.compactMap(\.coordinate)
            guard !coords.isEmpty else { continue }
            legGroups.append(LegGroup(mode: leg.transportMode, coords: coords))
        }

        let ungroupedCoords = grouped.ungrouped.compactMap(\.coordinate)
        if !ungroupedCoords.isEmpty {
            legGroups.append(LegGroup(mode: trip.transportMode ?? .driving, coords: ungroupedCoords))
        }

        return legGroups
    }
}
