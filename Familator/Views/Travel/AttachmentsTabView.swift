import SwiftUI

struct AttachmentsTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: AttachmentsViewModel
    @State private var showUploadPicker = false
    @State private var editingAttachment: TripAttachment?
    @State private var previewAttachment: TripAttachment?
    @State private var previewFileURL: URL?

    init(tripId: Int64) {
        _model = StateObject(wrappedValue: AttachmentsViewModel(tripId: tripId))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if let error = model.errorMessage {
                errorBanner(error)
            }
            if model.isBlockingLoad {
                Spacer()
                ProgressView()
                Spacer()
            } else if model.attachments.isEmpty {
                emptyState
            } else {
                attachmentsList
            }
            uploadBar
        }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load() }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task { await model.load() }
            }
        }
        .sheet(isPresented: $showUploadPicker) {
            AttachmentUploadSourcePicker { data, filename, mimeType in
                showUploadPicker = false
                Task { await model.upload(data: data, filename: filename, mimeType: mimeType) }
            }
        }
        .sheet(item: $editingAttachment) { attachment in
            EditAttachmentView(attachment: attachment) { title, description, category in
                editingAttachment = nil
                Task {
                    await model.updateMetadata(
                        attachment,
                        title: title,
                        description: description,
                        category: category
                    )
                }
            }
        }
        .sheet(item: Binding(
            get: { previewFileURL.map { PreviewItem(url: $0) } },
            set: { newValue in
                if newValue == nil {
                    cleanUpPreviewFile()
                    previewFileURL = nil
                    previewAttachment = nil
                }
            }
        )) { item in
            AttachmentQuickLookView(fileURL: item.url)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("\(model.attachments.count) attachment\(model.attachments.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if model.isRefreshing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal)
            .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperclip")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No attachments yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add photos, documents, or scanned files")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Attachments List

    private var attachmentsList: some View {
        List {
            ForEach(model.attachments) { attachment in
                AttachmentRow(
                    attachment: attachment,
                    signedURLProvider: { try await model.signedURL(for: attachment) },
                    onTap: { openPreview(attachment) },
                    onEdit: { editingAttachment = attachment }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let attachment = model.attachments[index]
                    Task { await model.delete(attachment) }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Upload Bar

    private var uploadBar: some View {
        VStack(spacing: 0) {
            Divider()
            if model.isUploading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Uploading…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                Button {
                    showUploadPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add attachment")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
    }

    // MARK: - Preview

    private func openPreview(_ attachment: TripAttachment) {
        previewAttachment = attachment
        Task {
            do {
                let url = try await model.downloadFile(for: attachment)
                previewFileURL = url
            } catch {
                model.errorMessage = error.localizedDescription
                previewAttachment = nil
            }
        }
    }

    private func cleanUpPreviewFile() {
        if let url = previewFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Preview Item

private struct PreviewItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Attachment Row

struct AttachmentRow: View {
    let attachment: TripAttachment
    let signedURLProvider: () async throws -> URL
    let onTap: () -> Void
    let onEdit: () -> Void

    @State private var thumbnailURL: URL?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                thumbnailView
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(attachment.category.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())

                        Text(attachment.formattedSize)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
        .task {
            if attachment.isImage {
                thumbnailURL = try? await signedURLProvider()
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if attachment.isImage, let url = thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderIcon
                default:
                    ProgressView().scaleEffect(0.6)
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            Color(.systemGray6)
            Image(systemName: attachment.category.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
