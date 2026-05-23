import SwiftUI

struct AddTripView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var destination = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    var onCreated: (Trip) -> Void

    private let tripService = TripService()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Destination", text: $destination)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Section {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(isLoading || destination.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isLoading { ProgressView() }
            }
        }
    }

    private func create() async {
        guard let userId = auth.currentUser?.id else { return }
        guard let workspaceId = workspaceVM.activeWorkspaceId else {
            errorMessage = "No workspace selected."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let trip = try await tripService.createTrip(
                ownerId: userId,
                destination: destination.trimmingCharacters(in: .whitespaces),
                workspaceId: workspaceId
            )
            onCreated(trip)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
