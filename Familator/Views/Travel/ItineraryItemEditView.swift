import SwiftUI

struct ItineraryItemEditView: View {
    enum Mode {
        case create
        case edit(TripItineraryItem)
    }

    let mode: Mode
    @ObservedObject var viewModel: ItineraryViewModel
    let onDismiss: () -> Void

    @State private var itemType: ItineraryItemType
    @State private var title: String
    @State private var descriptionText: String
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var hasStartTime: Bool
    @State private var startTime: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var provider: String
    @State private var confirmationNumber: String
    @State private var selectedLegId: Int64?
    @State private var selectedPlaceId: Int64?
    @State private var isSaving = false

    init(mode: Mode, viewModel: ItineraryViewModel, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.viewModel = viewModel
        self.onDismiss = onDismiss

        switch mode {
        case .create:
            _itemType = State(initialValue: .activity)
            _title = State(initialValue: "")
            _descriptionText = State(initialValue: "")
            _hasDate = State(initialValue: false)
            _date = State(initialValue: Date())
            _hasStartTime = State(initialValue: false)
            _startTime = State(initialValue: Date())
            _hasEndTime = State(initialValue: false)
            _endTime = State(initialValue: Date())
            _provider = State(initialValue: "")
            _confirmationNumber = State(initialValue: "")
            _selectedLegId = State(initialValue: nil)
            _selectedPlaceId = State(initialValue: nil)

        case .edit(let item):
            _itemType = State(initialValue: item.itemType)
            _title = State(initialValue: item.title)
            _descriptionText = State(initialValue: item.description ?? "")
            let parsedDate = item.date.flatMap { Self.parseDate($0) }
            _hasDate = State(initialValue: parsedDate != nil)
            _date = State(initialValue: parsedDate ?? Date())
            let parsedStart = item.startTime.flatMap { Self.parseTime($0) }
            _hasStartTime = State(initialValue: parsedStart != nil)
            _startTime = State(initialValue: parsedStart ?? Date())
            let parsedEnd = item.endTime.flatMap { Self.parseTime($0) }
            _hasEndTime = State(initialValue: parsedEnd != nil)
            _endTime = State(initialValue: parsedEnd ?? Date())
            _provider = State(initialValue: item.provider ?? "")
            _confirmationNumber = State(initialValue: item.confirmationNumber ?? "")
            _selectedLegId = State(initialValue: item.legId)
            _selectedPlaceId = State(initialValue: item.placeId)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $itemType) {
                        ForEach(ItineraryItemType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Title") {
                    TextField("Item title", text: $title)
                }

                Section("Date & Time") {
                    Toggle("Set date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                    Toggle("Set start time", isOn: $hasStartTime)
                    if hasStartTime {
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Set end time", isOn: $hasEndTime)
                    if hasEndTime {
                        DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Details") {
                    TextField("Provider", text: $provider)
                    TextField("Confirmation number", text: $confirmationNumber)
                }

                if !viewModel.legs.isEmpty {
                    Section("Leg") {
                        Picker("Leg", selection: $selectedLegId) {
                            Text("Unassigned").tag(nil as Int64?)
                            ForEach(viewModel.legs) { leg in
                                Text(leg.name).tag(leg.id as Int64?)
                            }
                        }
                    }
                }

                if !viewModel.places.isEmpty {
                    Section("Place") {
                        Picker("Place", selection: $selectedPlaceId) {
                            Text("None").tag(nil as Int64?)
                            ForEach(viewModel.places) { place in
                                Text(place.name).tag(place.id as Int64?)
                            }
                        }
                    }
                }

                Section("Description") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(isCreating ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private func save() {
        isSaving = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmation = confirmationNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            defer { isSaving = false }
            switch mode {
            case .create:
                await viewModel.addItem(
                    itemType: itemType,
                    title: trimmedTitle,
                    description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                    date: hasDate ? Self.formatDate(date) : nil,
                    startTime: hasStartTime ? Self.formatTime(startTime) : nil,
                    endTime: hasEndTime ? Self.formatTime(endTime) : nil,
                    confirmationNumber: trimmedConfirmation.isEmpty ? nil : trimmedConfirmation,
                    provider: trimmedProvider.isEmpty ? nil : trimmedProvider,
                    legId: selectedLegId,
                    placeId: selectedPlaceId
                )

            case .edit(let item):
                var update = TripItineraryItemUpdate()
                update.itemType = itemType
                update.title = trimmedTitle

                if !trimmedDesc.isEmpty { update.description = trimmedDesc } else { update.clearDescription = true }
                if hasDate { update.date = Self.formatDate(date) } else { update.clearDate = true }
                if hasStartTime { update.startTime = Self.formatTime(startTime) } else { update.clearStartTime = true }
                if hasEndTime { update.endTime = Self.formatTime(endTime) } else { update.clearEndTime = true }
                if !trimmedConfirmation.isEmpty { update.confirmationNumber = trimmedConfirmation } else { update.clearConfirmationNumber = true }
                if !trimmedProvider.isEmpty { update.provider = trimmedProvider } else { update.clearProvider = true }
                if let legId = selectedLegId { update.legId = legId } else { update.clearLegId = true }
                if let placeId = selectedPlaceId { update.placeId = placeId } else { update.clearPlaceId = true }

                await viewModel.updateItem(id: item.id, update: update)
            }

            onDismiss()
        }
    }

    // MARK: - Date/Time Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func parseTime(_ string: String) -> Date? {
        timeFormatter.date(from: string)
    }

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
