import SwiftUI

struct ContextsManagementView: View {
    @EnvironmentObject var auth: AuthService

    @State private var contexts: [TaskContext] = []
    @State private var newContextName = ""
    @State private var renameNameById: [Int64: String] = [:]
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let contextsService: ContextsServiceProtocol

    init(contextsService: ContextsServiceProtocol = ContextsService()) {
        self.contextsService = contextsService
    }

    var body: some View {
        List {
            Section("New context") {
                HStack {
                    TextField("Name", text: $newContextName)
                    Button("Add") { Task { await createContext() } }
                        .disabled(newContextName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }

            Section("Your contexts") {
                if contexts.isEmpty {
                    Text("No contexts yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(contexts) { context in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Name", text: binding(for: context))
                                Button("Save") { Task { await renameContext(context) } }
                                    .disabled(isLoading)
                            }
                        }
                    }
                    .onDelete(perform: deleteContext)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Contexts")
        .task { await loadContexts() }
    }

    private func binding(for context: TaskContext) -> Binding<String> {
        Binding(
            get: { renameNameById[context.id] ?? context.name },
            set: { renameNameById[context.id] = $0 }
        )
    }

    private func loadContexts() async {
        guard let userId = auth.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            contexts = try await contextsService.fetchContexts(userId: userId)
        } catch {
            errorMessage = UserFacingAsyncError.alertMessage(from: error)
        }
    }

    private func createContext() async {
        guard let userId = auth.currentUser?.id else { return }
        errorMessage = nil
        do {
            let created = try await contextsService.createContext(userId: userId, name: newContextName)
            contexts = (contexts + [created]).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            renameNameById[created.id] = created.name
            newContextName = ""
        } catch {
            errorMessage = UserFacingAsyncError.alertMessage(from: error)
        }
    }

    private func renameContext(_ context: TaskContext) async {
        guard let userId = auth.currentUser?.id else { return }
        errorMessage = nil
        do {
            let renamed = try await contextsService.renameContext(
                id: context.id,
                userId: userId,
                name: renameNameById[context.id] ?? context.name
            )
            if let index = contexts.firstIndex(where: { $0.id == context.id }) {
                contexts[index] = renamed
            }
            contexts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            renameNameById[renamed.id] = renamed.name
        } catch {
            errorMessage = UserFacingAsyncError.alertMessage(from: error)
        }
    }

    private func deleteContext(at offsets: IndexSet) {
        guard let userId = auth.currentUser?.id else { return }
        for index in offsets {
            let context = contexts[index]
            Task {
                do {
                    try await contextsService.deleteContext(id: context.id, userId: userId)
                    contexts.removeAll { $0.id == context.id }
                    renameNameById.removeValue(forKey: context.id)
                } catch {
                    errorMessage = UserFacingAsyncError.alertMessage(from: error)
                }
            }
        }
    }
}
