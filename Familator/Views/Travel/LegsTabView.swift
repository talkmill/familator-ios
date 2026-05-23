import SwiftUI

struct LegsTabView: View {
    let tripId: Int64

    @StateObject private var model: TripLegsViewModel
    @State private var showAddLeg = false
    @State private var newLegName = ""
    @State private var editingLeg: TripLeg?
    @State private var legToDelete: TripLeg?

    init(tripId: Int64) {
        self.tripId = tripId
        _model = StateObject(wrappedValue: TripLegsViewModel(tripId: tripId))
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
            } else if model.legs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No legs yet")
                        .font(.headline)
                    Text("Split your trip into segments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showAddLeg = true
                    } label: {
                        Label("Add Leg", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                Spacer()
            } else {
                List {
                    ForEach(model.legs) { leg in
                        LegRowView(leg: leg, onEdit: { editingLeg = leg })
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    legToDelete = leg
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { source, destination in
                        Task { await model.moveLeg(from: source, to: destination) }
                    }

                    // Inline add button as list footer
                    Button {
                        showAddLeg = true
                    } label: {
                        Label("Add Leg", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
                .environment(\.editMode, model.legs.count > 1 ? nil : .constant(.inactive))
            }
        }
        .alert("New Leg", isPresented: $showAddLeg) {
            TextField("Leg name", text: $newLegName)
            Button("Add") {
                Task {
                    await model.addLeg(name: newLegName)
                    newLegName = ""
                }
            }
            Button("Cancel", role: .cancel) { newLegName = "" }
        } message: {
            Text("Enter a name for the new leg.")
        }
        .sheet(item: $editingLeg) { leg in
            LegEditView(leg: leg, viewModel: model) { editingLeg = nil }
        }
        .alert("Remove leg?", isPresented: Binding(
            get: { legToDelete != nil },
            set: { if !$0 { legToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let leg = legToDelete {
                    Task { await model.deleteLeg(id: leg.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let leg = legToDelete {
                Text("\(leg.name) will be removed. Its places will become unassigned.")
            }
        }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load() }
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

// MARK: - Leg Row

private struct LegRowView: View {
    let leg: TripLeg
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(leg.name)
                        .font(.body)
                    Label(leg.transportMode.rawValue.capitalized, systemImage: transportIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var transportIcon: String {
        switch leg.transportMode {
        case .driving: return "car"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }
}
