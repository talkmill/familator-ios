import SwiftUI

@main
struct FamilatorApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()
    @StateObject private var workListsViewModel = WorkListsViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var toastManager = ToastManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(workspaceViewModel)
                .environmentObject(workListsViewModel)
                .environmentObject(profileViewModel)
                .environmentObject(toastManager)
                .toast(manager: toastManager)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GoogleSignInHelper.handle(url: url)
                }
        }
    }
}
