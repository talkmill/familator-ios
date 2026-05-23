import SwiftUI

struct EditAttachmentView: View {
    let attachment: TripAttachment
    let onSave: (String?, String?, AttachmentCategory?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var category: AttachmentCategory

    init(attachment: TripAttachment, onSave: @escaping (String?, String?, AttachmentCategory?) -> Void) {
        self.attachment = attachment
        self.onSave = onSave
        _title = State(initialValue: attachment.title)
        _description = State(initialValue: attachment.description)
        _category = State(initialValue: attachment.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                        .onChange(of: title) { newValue in
                            if newValue.count > 120 {
                                title = String(newValue.prefix(120))
                            }
                        }
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .onChange(of: description) { newValue in
                            if newValue.count > 1000 {
                                description = String(newValue.prefix(1000))
                            }
                        }
                    Text("\(description.count)/1000")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(AttachmentCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.systemImage)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Details") {
                    LabeledContent("File", value: attachment.originalFilename)
                    LabeledContent("Size", value: attachment.formattedSize)
                    LabeledContent("Type", value: attachment.mimeType)
                }
            }
            .navigationTitle("Edit Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.medium)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let newTitle = trimmedTitle != attachment.title ? trimmedTitle : nil
        let newDescription = description != attachment.description ? description : nil
        let newCategory = category != attachment.category ? category : nil

        onSave(newTitle, newDescription, newCategory)
    }
}
