import SwiftUI

struct TaskContextChipsView: View {
    let contexts: [TaskContext]

    var body: some View {
        if !contexts.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(contexts) { context in
                        Text(context.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct TaskContextPickerSection: View {
    @Binding var contexts: [TaskContext]
    @Binding var selectedContextIds: Set<Int64>
    @Binding var newContextName: String
    let onCreateContext: () -> Void

    var body: some View {
        Section("Contexts") {
            if !contexts.isEmpty {
                ForEach(contexts) { context in
                    Button {
                        if selectedContextIds.contains(context.id) {
                            selectedContextIds.remove(context.id)
                        } else {
                            selectedContextIds.insert(context.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedContextIds.contains(context.id) ? "checkmark.circle.fill" : "circle")
                            Text(context.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("New context", text: $newContextName)
                Button("Add", action: onCreateContext)
                    .disabled(newContextName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
