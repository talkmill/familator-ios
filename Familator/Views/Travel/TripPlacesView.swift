import SwiftUI

struct TripPlacesView: View {
    let tripId: Int64

    @StateObject private var model: TripPlacesViewModel
    @State private var showAddPlace = false
    @State private var editingPlace: TripPlace?
    @State private var placeToDelete: TripPlace?

    init(tripId: Int64) {
        self.tripId = tripId
        _model = StateObject(wrappedValue: TripPlacesViewModel(tripId: tripId))
    }

    var body: some View {
        Group {
            if model.isBlockingLoad {
                ProgressView()
            } else if model.places.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No places yet")
                        .font(.headline)
                    Text("Add your first stop")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.places) { place in
                        PlaceRowView(
                            place: place,
                            legName: model.legName(for: place.legId),
                            onRatingChange: { newRating in
                                Task { await model.updateRating(placeId: place.id, rating: newRating) }
                            },
                            onEdit: { editingPlace = place }
                        )
                        .contextMenu {
                            if !model.legs.isEmpty {
                                Menu("Assign to Leg") {
                                    Button("Unassigned") {
                                        Task {
                                            await model.updatePlace(
                                                id: place.id,
                                                update: TripPlaceUpdate(clearLegId: true)
                                            )
                                        }
                                    }
                                    ForEach(model.legs) { leg in
                                        Button(leg.name) {
                                            Task {
                                                await model.updatePlace(
                                                    id: place.id,
                                                    update: TripPlaceUpdate(legId: leg.id)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            Button {
                                editingPlace = place
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                placeToDelete = place
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        Task { await model.movePlace(from: source, to: destination) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddPlace = true } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            if !model.places.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAddPlace) {
            PlaceSearchView(viewModel: model) { showAddPlace = false }
        }
        .sheet(item: $editingPlace) { place in
            PlaceEditView(place: place, viewModel: model) { editingPlace = nil }
        }
        .alert("Remove place?", isPresented: Binding(
            get: { placeToDelete != nil },
            set: { if !$0 { placeToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let place = placeToDelete {
                    Task { await model.deletePlace(id: place.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let place = placeToDelete {
                Text("\(place.name) will be permanently removed.")
            }
        }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load() }
        }
    }
}

// MARK: - Place Row

struct PlaceRowView: View {
    let place: TripPlace
    let legName: String?
    let onRatingChange: (Int?) -> Void
    let onEdit: () -> Void

    @State private var rating: Int?

    init(place: TripPlace, legName: String? = nil, onRatingChange: @escaping (Int?) -> Void, onEdit: @escaping () -> Void) {
        self.place = place
        self.legName = legName
        self.onRatingChange = onRatingChange
        self.onEdit = onEdit
        _rating = State(initialValue: place.rating)
    }

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.body)
                    HStack(spacing: 8) {
                        if let legName {
                            Text(legName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        if let dateStr = place.date {
                            Text(dateStr)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let notes = place.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                StarRatingView(rating: $rating)
                    .onChange(of: rating) { newValue in
                        if newValue != place.rating {
                            onRatingChange(newValue)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: place.rating) { newValue in
            rating = newValue
        }
    }
}

// MARK: - TripPlace + Identifiable for sheet(item:)

extension TripPlace: Hashable {
    static func == (lhs: TripPlace, rhs: TripPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
