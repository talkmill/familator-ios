import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum GoogleSignInHelper {
#if canImport(GoogleSignIn)
    @MainActor
    static func signIn() async -> String? {
        guard let clientID = AppConfig.googleClientID else { return nil }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            return nil
        }

        let result = try? await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let user = result?.user else { return nil }
        return user.idToken?.tokenString
    }

    @MainActor
    static func accessToken() async -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        return user.accessToken.tokenString
    }

    static func handle(url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }
#else
    @MainActor
    static func signIn() async -> String? { nil }
    @MainActor
    static func accessToken() async -> String? { nil }
    static func handle(url: URL) {}
#endif
}
