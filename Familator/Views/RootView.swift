import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @State private var hasSession = false

    var body: some View {
        Group {
            if hasSession {
                MainTabView()
            } else {
                SignInView(onSignedIn: { hasSession = true })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            hasSession = auth.currentSession != nil
            if let userId = auth.currentUser?.id {
                await workspaceVM.loadWorkspaces(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            hasSession = auth.currentSession != nil
            if let userId = auth.currentUser?.id {
                Task { await workspaceVM.loadWorkspaces(userId: userId) }
            } else {
                workspaceVM.reset()
            }
        }
    }
}

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
    static let familatorDataDidChange = Notification.Name("familatorDataDidChange")
}
