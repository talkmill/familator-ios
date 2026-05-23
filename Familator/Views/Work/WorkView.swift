import SwiftUI

/// Destination for Todo tab: either a list (by id) or a filter (due-now, etc.).
enum WorkDestination: Hashable {
    case list(Int64)
    case filter(String)
}

struct WorkView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workLists: WorkListsViewModel
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @Environment(\.scenePhase) private var scenePhase
    var selectedListId: Int64?
    var selectedFilter: String?

    @State private var path: [WorkDestination] = []
    @State private var showCreateList = false
    @State private var favoriteListIds: Set<Int64> = []
    @State private var favoriteUpdatesInFlight: Set<Int64> = []
    @State private var favoritesErrorMessage: String?
    private let pollIntervalNanoseconds: UInt64 = 30_000_000_000
    private let dashboardService = DashboardService()

    init(selectedListId: Int64? = nil, selectedFilter: String? = nil) {
        self.selectedListId = selectedListId
        self.selectedFilter = selectedFilter
    }

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
            .navigationTitle("Work")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WorkspaceNavButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if workLists.isRefreshing {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New list") { showCreateList = true }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCreateList) {
                CreateListView(onCreated: { list in
                    workLists.appendList(list)
                    showCreateList = false
                })
                .environmentObject(auth)
            }
            .navigationDestination(for: WorkDestination.self) { dest in
                switch dest {
                case .list(let listId):
                    TodoListView(listId: listId)
                        .environmentObject(auth)
                case .filter(let key):
                    FilteredTaskListView(filterKey: key)
                        .environmentObject(auth)
                }
            }
            .onAppear {
                if path.isEmpty, let id = selectedListId {
                    path = [.list(id)]
                } else if path.isEmpty, let key = selectedFilter {
                    path = [.filter(key)]
                }
            }
            .task {
                await refreshWorkData()
            }
            .task(id: auth.currentUser?.id) {
                guard auth.currentUser?.id != nil else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                    guard !Task.isCancelled else { return }
                    await refreshWorkData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
                Task { await refreshWorkData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                Task { await refreshWorkData() }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { await refreshWorkData() }
                }
            }
            .alert("Favorites", isPresented: favoritesAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(favoritesErrorMessage ?? "Could not update favorites.")
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if workLists.isBlockingLoad {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section("Lists") {
                    ForEach(workLists.lists) { list in
                        listRow(list)
                    }
                }
                Section("Filters") {
                    filterLink("current", label: "Current")
                    filterLink("due-now", label: "Due now")
                    filterLink("upcoming", label: "Upcoming")
                    filterLink("next-week", label: "Next week")
                    filterLink("all", label: "All tasks")
                    filterLink("routines", label: "Recurring")
                    NavigationLink {
                        ContextsManagementView()
                            .environmentObject(auth)
                    } label: {
                        Text("Manage contexts")
                    }
                }
            }
        }
    }

    private func listRow(_ list: FamilatorList) -> some View {
        HStack(spacing: 8) {
            NavigationLink(value: WorkDestination.list(list.id)) {
                HStack {
                    Text(list.name)
                    if list.isShared {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Button {
                Task { await toggleListFavorite(listId: list.id) }
            } label: {
                Image(systemName: favoriteListIds.contains(list.id) ? "star.fill" : "star")
                    .foregroundStyle(favoriteListIds.contains(list.id) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(favoriteUpdatesInFlight.contains(list.id))
            .accessibilityLabel(
                favoriteListIds.contains(list.id)
                    ? "Remove \(list.name) from favorites"
                    : "Add \(list.name) to favorites"
            )
        }
    }

    private var favoritesAlertBinding: Binding<Bool> {
        Binding(
            get: { favoritesErrorMessage != nil },
            set: { isPresented in
                if !isPresented { favoritesErrorMessage = nil }
            }
        )
    }

    private func filterLink(_ key: String, label: String) -> some View {
        NavigationLink(value: WorkDestination.filter(key)) {
            Text(label)
        }
    }

    private func refreshWorkData() async {
        await workLists.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id)
        await loadFavorites()
    }

    private func loadFavorites() async {
        guard let userId = auth.currentUser?.id else {
            favoriteListIds = []
            return
        }
        do {
            let rows = try await dashboardService.fetchFavorites(userId: userId)
            favoriteListIds = Set(
                rows
                    .filter { $0.itemType == DashboardFavoriteRow.typeList }
                    .compactMap(\.listId)
            )
        } catch {
            favoriteListIds = []
        }
    }

    private func toggleListFavorite(listId: Int64) async {
        guard let userId = auth.currentUser?.id else { return }
        guard !favoriteUpdatesInFlight.contains(listId) else { return }

        favoriteUpdatesInFlight.insert(listId)
        defer { favoriteUpdatesInFlight.remove(listId) }
        favoritesErrorMessage = nil

        do {
            let existing = try await dashboardService.fetchFavorites(userId: userId)
            let activeListIds = Set(workLists.lists.map(\.id))
            var normalized: [(itemType: String, listId: Int64?, filterKey: String?)] = existing.compactMap { row in
                if row.itemType == DashboardFavoriteRow.typeList {
                    guard let id = row.listId, activeListIds.contains(id) else { return nil }
                    return (DashboardFavoriteRow.typeList, id, nil)
                }
                if row.itemType == DashboardFavoriteRow.typeFilter, let key = row.filterKey {
                    return (DashboardFavoriteRow.typeFilter, nil, key)
                }
                return nil
            }

            if let idx = normalized.firstIndex(where: { $0.itemType == DashboardFavoriteRow.typeList && $0.listId == listId }) {
                normalized.remove(at: idx)
            } else {
                guard normalized.count < 5 else {
                    favoritesErrorMessage = "You can only pin up to 5 favorites."
                    return
                }
                normalized.append((DashboardFavoriteRow.typeList, listId, nil))
            }

            try await dashboardService.setFavorites(userId: userId, favorites: normalized)
            favoriteListIds = Set(
                normalized
                    .filter { $0.itemType == DashboardFavoriteRow.typeList }
                    .compactMap(\.listId)
            )
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            favoritesErrorMessage = error.localizedDescription
        }
    }
}
