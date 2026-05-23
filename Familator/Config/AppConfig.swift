import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            fatalError("SUPABASE_URL is missing from Info.plist. Set it in Config.xcconfig and ensure the project uses Config.xcconfig.")
        }
        let urlString = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard !urlString.isEmpty,
              urlString != "https://your-project.supabase.co",
              let parsed = URL(string: urlString),
              let host = parsed.host, !host.isEmpty else {
            fatalError(
                "SUPABASE_URL is invalid (raw: \"\(raw)\"). Use a valid URL in Config.xcconfig (e.g. SUPABASE_URL = \"https://xxx.supabase.co\") and clean build."
            )
        }
        return parsed
    }

    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    /// Google iOS client ID for native Sign-In (optional; set in Info.plist as GOOGLE_CLIENT_ID)
    static var googleClientID: String? {
        trimmedInfoString("GOOGLE_CLIENT_ID")
    }

    /// Google Places API key for HTTP autocomplete + details (optional; set in Info.plist as GOOGLE_PLACES_API_KEY)
    static var googlePlacesAPIKey: String? {
        trimmedInfoString("GOOGLE_PLACES_API_KEY")
    }

    private static func trimmedInfoString(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return t.isEmpty ? nil : t
    }
}
