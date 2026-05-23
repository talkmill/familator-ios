import SwiftUI

struct TripsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @StateObject private var viewModel = TripsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showAddTrip = false
    @State private var tripToDelete: Trip?
    @State private var showDeleteConfirmation = false
    private let pollIntervalNanoseconds: UInt64 = 30_000_000_000

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Trips")
                .navigationDestination(for: Int64.self) { tripId in
                    TripDetailView(tripId: tripId)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        WorkspaceNavButton()
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.isRefreshing {
                            ProgressView()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("New trip") { showAddTrip = true }
                            .fontWeight(.semibold)
                    }
                }
                .sheet(isPresented: $showAddTrip) {
                    AddTripView(onCreated: { trip in
                        viewModel.appendTrip(trip)
                        showAddTrip = false
                    })
                    .environmentObject(auth)
                    .environmentObject(profile)
                    .environmentObject(workspaceVM)
                }
                .confirmationDialog(
                    "Delete \"\(tripToDelete?.destination ?? "trip")\"?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        if let trip = tripToDelete {
                            Task { await viewModel.deleteTrip(trip) }
                        }
                    }
                }
                .alert("Error", isPresented: mutationErrorBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.mutationError ?? "Something went wrong.")
                }
                .task(id: workspaceVM.activeWorkspaceId) {
                    await loadTrips()
                }
                .task(id: auth.currentUser?.id) {
                    guard auth.currentUser?.id != nil else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                        guard !Task.isCancelled else { return }
                        await loadTrips()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
                    Task { await loadTrips() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                    Task { await loadTrips() }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        Task { await loadTrips() }
                    }
                }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if workspaceVM.activeWorkspaceId == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isBlockingLoad {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 16) {
                Text("Could not load trips")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadTrips() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.trips.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "airplane")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No trips yet")
                    .font(.headline)
                Text("Tap \"New trip\" to plan your first adventure.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(TripStatus.allCases) { status in
                    let tripsInStatus = tripsByStatus(status)
                    if !tripsInStatus.isEmpty {
                        Section(status.displayName) {
                            ForEach(tripsInStatus) { trip in
                                NavigationLink(value: trip.id) {
                                    TripRow(trip: trip)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        tripToDelete = trip
                                        showDeleteConfirmation = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var mutationErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.mutationError != nil },
            set: { isPresented in
                if !isPresented { viewModel.mutationError = nil }
            }
        )
    }

    private func tripsByStatus(_ status: TripStatus) -> [Trip] {
        viewModel.trips.filter { $0.status == status }
    }

    private func loadTrips() async {
        await viewModel.load(workspaceId: workspaceVM.activeWorkspaceId)
    }
}
