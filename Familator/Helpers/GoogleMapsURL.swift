import Foundation

enum GoogleMapsURL {
    static func build(from places: [TripPlace]) -> URL? {
        let geocoded = places.filter { $0.lat != nil && $0.lng != nil }
        guard geocoded.count >= 2 else { return nil }

        let origin = geocoded[0]
        let destination = geocoded[geocoded.count - 1]
        let waypoints = Array(geocoded.dropFirst().dropLast())

        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: displayValue(origin)),
            URLQueryItem(name: "destination", value: displayValue(destination)),
            URLQueryItem(name: "travelmode", value: "driving"),
        ]

        if let placeId = origin.googlePlaceId?.trimmingCharacters(in: .whitespaces), !placeId.isEmpty {
            queryItems.append(URLQueryItem(name: "origin_place_id", value: placeId))
        }

        if let placeId = destination.googlePlaceId?.trimmingCharacters(in: .whitespaces), !placeId.isEmpty {
            queryItems.append(URLQueryItem(name: "destination_place_id", value: placeId))
        }

        if !waypoints.isEmpty {
            let waypointStr = waypoints.map { displayValue($0) }.joined(separator: "|")
            queryItems.append(URLQueryItem(name: "waypoints", value: waypointStr))

            let waypointPlaceIds = waypoints.compactMap { place -> String? in
                guard let id = place.googlePlaceId?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
                return id
            }
            if waypointPlaceIds.count == waypoints.count {
                queryItems.append(URLQueryItem(name: "waypoint_place_ids", value: waypointPlaceIds.joined(separator: "|")))
            }
        }

        components.queryItems = queryItems
        return components.url
    }

    private static func displayValue(_ place: TripPlace) -> String {
        let name = place.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty, let lat = place.lat, let lng = place.lng {
            return "\(lat),\(lng)"
        }
        return name.replacingOccurrences(of: "|", with: " ")
    }
}
