import SwiftUI

struct CreateListView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    var onCreated: (FamilatorList) -> Void

    private let listsService: ListsServiceProtocol

    init(onCreated: @escaping (FamilatorList) -> Void, listsService: ListsServiceProtocol = ListsService()) {
        self.onCreated = onCreated
        self.listsService = listsService
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("List name", text: $name)
                TextField("Description (optional)", text: $description)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Section {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New list")
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
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await listsService.createList(ownerId: userId, name: name.trimmingCharacters(in: .whitespaces), description: description.isEmpty ? nil : description, isInbox: false)
            onCreated(list)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
