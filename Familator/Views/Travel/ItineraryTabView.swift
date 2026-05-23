import SwiftUI

struct ItineraryTabView: View {
    let tripId: Int64
    let workspaceId: String
    let ownerId: UUID

    @StateObject private var model: ItineraryViewModel
    @State private var showAddItem = false
    @State private var editingItem: TripItineraryItem?
    @State private var itemToDelete: TripItineraryItem?

    init(tripId: Int64, workspaceId: String, ownerId: UUID) {
        self.tripId = tripId
        self.workspaceId = workspaceId
        self.ownerId = ownerId
        _model = StateObject(wrappedValue: ItineraryViewModel(tripId: tripId, workspaceId: workspaceId, ownerId: ownerId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.errorMessage {
                errorBanner(error)
            }

            if model.isBlockingLoad {
                Spacer()
                ProgressView()
                Spacer()
            } else if model.items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No itinerary items yet")
                        .font(.headline)
                    Text("Plan your trip schedule")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                Spacer()
            } else {
                itemList
            }
        }
        .sheet(isPresented: $showAddItem) {
            ItineraryItemEditView(mode: .create, viewModel: model) { showAddItem = false }
        }
        .sheet(item: $editingItem) { item in
            ItineraryItemEditView(mode: .edit(item), viewModel: model) { editingItem = nil }
        }
        .alert("Remove item?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let item = itemToDelete {
                    Task { await model.deleteItem(id: item.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let item = itemToDelete {
                Text("\(item.title) will be permanently removed.")
            }
        }
        .task { await model.load() }
    }

    // MARK: - Item List

    @ViewBuilder
    private var itemList: some View {
        let groups = model.groupedItems
        let hasLegs = !model.legs.isEmpty

        List {
            if hasLegs {
                ForEach(groups) { group in
                    Section(header: Text(group.leg?.name ?? "Unassigned")) {
                        itemRows(group.items)
                    }
                }
            } else {
                itemRows(model.items)
            }

            Button {
                showAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus.circle")
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private func itemRows(_ sectionItems: [TripItineraryItem]) -> some View {
        ForEach(sectionItems) { item in
            ItineraryRowView(item: item, legName: model.legName(for: item.legId), onEdit: { editingItem = item })
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        itemToDelete = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .onMove { source, destination in
            Task { await model.moveItem(from: source, to: destination, sectionItems: sectionItems) }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button {
                model.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Itinerary Row

private struct ItineraryRowView: View {
    let item: TripItineraryItem
    let legName: String?
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: item.itemType.icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)

                    HStack(spacing: 8) {
                        if let date = item.date {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let timeRange = formattedTimeRange {
                            Text(timeRange)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let provider = item.provider, !provider.isEmpty {
                            Text(provider)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if let confirmation = item.confirmationNumber, !confirmation.isEmpty {
                    Text(confirmation)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var formattedTimeRange: String? {
        let start = item.startTime.map { formatTime($0) }
        let end = item.endTime.map { formatTime($0) }

        switch (start, end) {
        case let (s?, e?): return "\(s) – \(e)"
        case let (s?, nil): return s
        default: return nil
        }
    }

    private func formatTime(_ time: String) -> String {
        // time comes as "HH:mm:ss" from DB, display as "HH:mm"
        let parts = time.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(parts[1])"
        }
        return time
    }
}
