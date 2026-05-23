import MapKit
import SwiftUI

@available(iOS 17.0, *)
struct RouteTabView: View {
    let tripId: Int64
    let trip: Trip
    @StateObject private var viewModel = RouteTabViewModel()
    @EnvironmentObject private var toastManager: ToastManager

    init(trip: Trip) {
        self.tripId = trip.id
        self.trip = trip
    }

    var body: some View {
        ZStack {
            RouteMapView(
                places: viewModel.orderedGeocodedPlaces,
                routeResult: viewModel.routeResult,
                selectedPlaceId: $viewModel.selectedPlaceId
            )

            VStack {
                TransportModePicker(selectedMode: $viewModel.transportMode) { mode in
                    Task {
                        await viewModel.changeTransportMode(to: mode)
                    }
                }
                .padding(.horizontal)

                if !viewModel.legs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.legs) { leg in
                                LegModePill(leg: leg) { mode in
                                    Task {
                                        await viewModel.changeLegTransportMode(legId: leg.id, to: mode)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    if let result = viewModel.routeResult, result.totalDistanceKm > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.formatDistance(result.totalDistanceKm))
                                    .font(.headline)
                                Text(viewModel.formatDuration(result.totalDurationMin))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let url = GoogleMapsURL.build(from: viewModel.orderedGeocodedPlaces) {
                                Link(destination: url) {
                                    Label("Google Maps", systemImage: "map")
                                        .font(.subheadline.bold())
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    if viewModel.canOptimize {
                        Button {
                            Task { await viewModel.optimizeRoute() }
                        } label: {
                            if viewModel.isOptimizing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Label("Optimize", systemImage: "arrow.triangle.swap")
                                    .font(.subheadline.bold())
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOptimizing)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 8)
            }

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial.opacity(0.5))
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: selectedPlace) { place in
            PlaceDetailSheet(
                place: livePlace(for: place),
                index: placeIndex(for: place)
            ) {
                Task { await viewModel.toggleAnchor(placeId: place.id) }
            }
        }
        .task {
            viewModel.showToast = { [weak toastManager] variant, message in
                toastManager?.show(variant, message: message)
            }
            viewModel.setTrip(trip)
            await viewModel.load(tripId: tripId)
        }
    }

    private var selectedPlace: Binding<TripPlace?> {
        Binding(
            get: {
                guard let id = viewModel.selectedPlaceId else { return nil }
                return viewModel.orderedGeocodedPlaces.first { $0.id == id }
            },
            set: { viewModel.selectedPlaceId = $0?.id }
        )
    }

    private func placeIndex(for place: TripPlace) -> Int {
        viewModel.orderedGeocodedPlaces.firstIndex(where: { $0.id == place.id }) ?? 0
    }

    private func livePlace(for place: TripPlace) -> TripPlace {
        viewModel.places.first(where: { $0.id == place.id }) ?? place
    }
}

@available(iOS 17.0, *)
private struct LegModePill: View {
    let leg: TripLeg
    let onChange: (TransportMode) -> Void

    @State private var mode: TransportMode

    init(leg: TripLeg, onChange: @escaping (TransportMode) -> Void) {
        self.leg = leg
        self.onChange = onChange
        _mode = State(initialValue: leg.transportMode)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(leg.name)
                .font(.caption)
                .lineLimit(1)

            Menu {
                ForEach(TransportMode.allCases, id: \.self) { transportMode in
                    Button {
                        mode = transportMode
                        onChange(transportMode)
                    } label: {
                        Label(transportMode.displayName, systemImage: transportMode.systemImage)
                    }
                }
            } label: {
                Image(systemName: mode.systemImage)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onChange(of: leg.transportMode) { _, newValue in
            mode = newValue
        }
    }
}

@available(iOS 17.0, *)
private struct PlaceDetailSheet: View {
    let place: TripPlace
    let index: Int
    let onToggleAnchor: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        PlaceMarkerView(index: index, color: PlaceColors.color(forIndex: index))
                        Text(place.name)
                            .font(.headline)
                        Spacer()
                        Button {
                            onToggleAnchor()
                        } label: {
                            Image(systemName: place.isRouteAnchor ? "pin.fill" : "pin")
                                .foregroundStyle(place.isRouteAnchor ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let notes = place.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                    }
                }

                if let rating = place.rating {
                    Section("Rating") {
                        HStack {
                            ForEach(1 ... 5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(star <= rating ? .yellow : .gray)
                            }
                        }
                    }
                }

                if let lat = place.lat, let lng = place.lng {
                    Section("Coordinates") {
                        Text(String(format: "%.6f, %.6f", lat, lng))
                            .font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
