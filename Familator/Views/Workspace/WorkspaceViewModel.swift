import Foundation
import SwiftUI

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var activeWorkspace: Workspace?
    @Published var isLoading = false
    @Published var showWorkspacePicker = false

    private let service: WorkspaceServiceProtocol
    private let defaults: UserDefaults

    static let activeWorkspaceIdKey = "activeWorkspaceId"

    init(service: WorkspaceServiceProtocol = WorkspaceService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    var activeWorkspaceId: String? {
        activeWorkspace?.id
    }

    func loadWorkspaces(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchWorkspaces()
            workspaces = fetched

            // Resolve active workspace: UserDefaults → profile → personal fallback
            let cachedId = defaults.string(forKey: Self.activeWorkspaceIdKey)

            if let cachedId, let match = fetched.first(where: { $0.id == cachedId }) {
                activeWorkspace = match
            } else {
                // Try fetching from profile
                let profileId = try? await service.fetchActiveWorkspaceId(userId: userId)
                if let profileId, let match = fetched.first(where: { $0.id == profileId }) {
                    activeWorkspace = match
                    defaults.set(profileId, forKey: Self.activeWorkspaceIdKey)
                } else {
                    // Fall back to personal workspace
                    let personal = fetched.first(where: { $0.isPersonal }) ?? fetched.first
                    activeWorkspace = personal
                    if let id = personal?.id {
                        defaults.set(id, forKey: Self.activeWorkspaceIdKey)
                    }
                }
            }
        } catch {
            workspaces = []
            activeWorkspace = nil
        }
    }

    func setActiveWorkspace(_ workspace: Workspace, userId: UUID) {
        activeWorkspace = workspace
        defaults.set(workspace.id, forKey: Self.activeWorkspaceIdKey)
        showWorkspacePicker = false

        Task {
            try? await service.updateActiveWorkspace(userId: userId, workspaceId: workspace.id)
        }

        NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
    }

    func reset() {
        workspaces = []
        activeWorkspace = nil
        isLoading = false
        showWorkspacePicker = false
        defaults.removeObject(forKey: Self.activeWorkspaceIdKey)
    }
}
