import SwiftUI

struct PlaceEditView: View {
    let place: TripPlace
    @ObservedObject var viewModel: TripPlacesViewModel
    let onDismiss: () -> Void

    @State private var name: String
    @State private var notes: String
    @State private var rating: Int?
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var selectedLegId: Int64?
    @State private var isSaving = false

    init(place: TripPlace, viewModel: TripPlacesViewModel, onDismiss: @escaping () -> Void) {
        self.place = place
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _name = State(initialValue: place.name)
        _notes = State(initialValue: place.notes ?? "")
        _rating = State(initialValue: place.rating)
        _selectedLegId = State(initialValue: place.legId)
        let parsedDate = place.date.flatMap { Self.parseDate($0) }
        _hasDate = State(initialValue: parsedDate != nil)
        _date = State(initialValue: parsedDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Place name", text: $name)
                }

                Section("Rating") {
                    StarRatingView(rating: $rating)
                }

                Section("Date") {
                    Toggle("Set visit date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
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

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        var update = TripPlaceUpdate()
        update.name = trimmedName
        if let rating {
            update.rating = rating
        } else {
            update.clearRating = true
        }
        if !trimmedNotes.isEmpty {
            update.notes = trimmedNotes
        } else {
            update.clearNotes = true
        }
        if hasDate {
            update.date = Self.formatDate(date)
        } else {
            update.clearDate = true
        }
        if let selectedLegId {
            update.legId = selectedLegId
        } else {
            update.clearLegId = true
        }

        Task {
            await viewModel.updatePlace(id: place.id, update: update)
            isSaving = false
            onDismiss()
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
