import SwiftUI

struct TripDetailView: View {
    let tripId: Int64
    @StateObject private var viewModel = TripDetailViewModel()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let _ = viewModel.trip {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        tabBar
                        tabContent
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: viewModel.errorMessage != nil ? "exclamationmark.triangle" : "airplane.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(viewModel.errorMessage ?? "Trip not found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.trip?.destination ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(tripId: tripId)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Destination
            HStack {
                if viewModel.isEditingDestination {
                    TextField("Destination", text: $viewModel.destinationDraft, onCommit: {
                        Task { await viewModel.saveDestination() }
                    })
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                } else {
                    Text(viewModel.destinationDraft)
                        .font(.title2)
                        .fontWeight(.bold)
                        .onTapGesture {
                            viewModel.isEditingDestination = true
                        }
                }

                Spacer()

                statusBadge
            }

            // Date pickers
            HStack(spacing: 16) {
                datePicker(label: "Start", value: viewModel.localStartDate) { newDate in
                    Task { await viewModel.saveStartDate(newDate) }
                }
                datePicker(label: "End", value: viewModel.localEndDate) { newDate in
                    Task { await viewModel.saveEndDate(newDate) }
                }
            }

            // Nights count and transport mode
            HStack {
                if let nights = viewModel.nights {
                    Label("\(nights) night\(nights == 1 ? "" : "s")", systemImage: "moon.stars")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Transport", selection: Binding(
                    get: { viewModel.localTransportMode },
                    set: { mode in Task { await viewModel.saveTransportMode(mode) } }
                )) {
                    Label("Driving", systemImage: "car").tag(TransportMode.driving)
                    Label("Walking", systemImage: "figure.walk").tag(TransportMode.walking)
                    Label("Cycling", systemImage: "bicycle").tag(TransportMode.cycling)
                }
                .pickerStyle(.menu)
                .labelStyle(.iconOnly)
            }

            if viewModel.isSaving {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
    }

    private var statusBadge: some View {
        Text(viewModel.status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .planning: return .orange
        case .upcoming: return .blue
        case .inProgress: return .green
        case .past: return .secondary
        }
    }

    @ViewBuilder
    private func datePicker(label: String, value: String?, onChange: @escaping (String?) -> Void) -> some View {
        let currentDate: Date? = value.flatMap { Self.dateFormatter.date(from: $0) }

        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let currentDate {
                DatePicker(
                    label,
                    selection: Binding(
                        get: { currentDate },
                        set: { date in onChange(Self.dateFormatter.string(from: date)) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            } else {
                Button {
                    onChange(Self.dateFormatter.string(from: Date()))
                } label: {
                    Text("Set \(label.lowercased()) date")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(TripTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.activeTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.caption)
                                Text(tab.label)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            Rectangle()
                                .fill(viewModel.activeTab == tab ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .foregroundStyle(viewModel.activeTab == tab ? Color.accentColor : .secondary)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        if let trip = viewModel.trip {
            switch viewModel.activeTab {
            case .checklist:
                ChecklistTabView(listId: trip.listId)
                    .frame(maxWidth: .infinity, minHeight: 300)
            case .places:
                TripPlacesView(tripId: trip.id)
                    .frame(maxWidth: .infinity, minHeight: 300)
            case .legs:
                LegsTabView(tripId: trip.id)
                    .frame(maxWidth: .infinity, minHeight: 300)
            case .notes:
                TripNotesView(listId: trip.listId)
                    .frame(maxWidth: .infinity, minHeight: 300)
            case .itinerary:
                ItineraryTabView(tripId: trip.id, workspaceId: trip.workspaceId, ownerId: trip.ownerId)
                    .frame(maxWidth: .infinity, minHeight: 300)
            case .route:
                if #available(iOS 17.0, *) {
                    RouteTabView(trip: trip)
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    tabPlaceholder(tab: viewModel.activeTab)
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            default:
                tabPlaceholder(tab: viewModel.activeTab)
                    .frame(maxWidth: .infinity, minHeight: 300)
            }
        } else {
            tabPlaceholder(tab: viewModel.activeTab)
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func tabPlaceholder(tab: TripTab) -> some View {
        VStack(spacing: 12) {
            Image(systemName: tab.icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("\(tab.label) coming soon")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}
