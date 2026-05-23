import Foundation
import Supabase

enum SupabaseManager {
    static let client: Supabase.SupabaseClient = {
        Supabase.SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }()
}
