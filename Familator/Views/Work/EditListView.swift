import SwiftUI

struct EditListView: View {
    @EnvironmentObject var auth: AuthService
    let list: FamilatorList
    @State private var name: String
    @State private var description: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onDone: () -> Void

    private let listsService = ListsService()

    init(list: FamilatorList, onDone: @escaping () -> Void) {
        self.list = list
        _name = State(initialValue: list.name)
        _description = State(initialValue: list.description ?? "")
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Section {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edit list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
            }
            .overlay {
                if isLoading { ProgressView() }
            }
        }
    }

    private func save() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await listsService.updateList(id: list.id, name: name.trimmingCharacters(in: .whitespaces), description: description.isEmpty ? nil : description, isShared: nil)
            onDone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
