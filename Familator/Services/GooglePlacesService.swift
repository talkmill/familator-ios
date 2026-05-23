import Foundation

struct PlaceSuggestion: Identifiable {
    let id: String
    let displayName: String
    let formattedAddress: String?
}

struct PlaceDetails {
    let name: String
    let lat: Double?
    let lng: Double?
    let googlePlaceId: String
}

final class GooglePlacesService {
    private let session = URLSession.shared

    var isAvailable: Bool {
        AppConfig.googlePlacesAPIKey != nil
    }

    func autocomplete(query: String) async throws -> [PlaceSuggestion] {
        guard let apiKey = AppConfig.googlePlacesAPIKey else { return [] }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:autocomplete")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["input": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await session.data(for: request)
        if let status = (httpResponse as? HTTPURLResponse)?.statusCode, status >= 400 {
            throw GooglePlacesError.httpError(status)
        }
        let response = try JSONDecoder().decode(AutocompleteResponse.self, from: data)

        return response.suggestions?.compactMap { suggestion -> PlaceSuggestion? in
            guard let prediction = suggestion.placePrediction else { return nil }
            return PlaceSuggestion(
                id: prediction.placeId,
                displayName: prediction.text.text,
                formattedAddress: prediction.structuredFormat?.secondaryText?.text
            )
        } ?? []
    }

    func fetchDetails(placeId: String) async throws -> PlaceDetails? {
        guard let apiKey = AppConfig.googlePlacesAPIKey else { return nil }
        guard let encodedId = placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://places.googleapis.com/v1/places/\(encodedId)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("displayName,location,id", forHTTPHeaderField: "X-Goog-FieldMask")

        let (data, httpResponse) = try await session.data(for: request)
        if let status = (httpResponse as? HTTPURLResponse)?.statusCode, status >= 400 {
            throw GooglePlacesError.httpError(status)
        }
        let response = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)

        return PlaceDetails(
            name: response.displayName.text,
            lat: response.location?.latitude,
            lng: response.location?.longitude,
            googlePlaceId: response.id
        )
    }
}

enum GooglePlacesError: LocalizedError {
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Google Places API error (HTTP \(code))"
        }
    }
}

// MARK: - API Response Types

private struct AutocompleteResponse: Decodable {
    let suggestions: [AutocompleteSuggestion]?
}

private struct AutocompleteSuggestion: Decodable {
    let placePrediction: PlacePrediction?
}

private struct PlacePrediction: Decodable {
    let placeId: String
    let text: LocalizedText
    let structuredFormat: StructuredFormat?
}

private struct StructuredFormat: Decodable {
    let secondaryText: LocalizedText?
}

private struct LocalizedText: Decodable {
    let text: String
}

private struct PlaceDetailsResponse: Decodable {
    let id: String
    let displayName: LocalizedText
    let location: LatLng?
}

private struct LatLng: Decodable {
    let latitude: Double
    let longitude: Double
}
