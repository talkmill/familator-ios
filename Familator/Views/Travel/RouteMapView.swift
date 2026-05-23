import MapKit
import SwiftUI

@available(iOS 17.0, *)
struct RouteMapView: View {
    let places: [TripPlace]
    let routeResult: MultiLegRouteResult?
    @Binding var selectedPlaceId: Int64?

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedPlaceId) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                if let coordinate = place.coordinate {
                    Annotation(place.name, coordinate: coordinate) {
                        PlaceMarkerView(index: index, color: PlaceColors.color(forIndex: index))
                    }
                    .tag(place.id)
                }
            }

            if let routeResult {
                // Draw per-leg polylines with mode-based colors.
                ForEach(Array(routeResult.legs.enumerated()), id: \.offset) { _, leg in
                    if leg.polylineCoords.count >= 2 {
                        MapPolyline(coordinates: leg.polylineCoords)
                            .stroke(polylineColor(for: leg.mode), lineWidth: 4)
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onChange(of: places.map(\.id)) {
            fitCamera()
        }
        .onAppear {
            fitCamera()
        }
    }

    private func fitCamera() {
        let coords = places.compactMap(\.coordinate)
        guard !coords.isEmpty else { return }

        if coords.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: coords[0],
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
            return
        }

        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLng = coords[0].longitude
        var maxLng = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }

        let padding = 0.2
        let latDelta = max((maxLat - minLat) * (1 + padding), 0.01)
        let lngDelta = max((maxLng - minLng) * (1 + padding), 0.01)
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        cameraPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        ))
    }

    private func polylineColor(for mode: TransportMode) -> Color {
        switch mode {
        case .driving: return .blue
        case .walking: return .orange
        case .cycling: return .green
        }
    }
}
