import SwiftUI

struct LegEditView: View {
    let leg: TripLeg
    @ObservedObject var viewModel: TripLegsViewModel
    let onDismiss: () -> Void

    @State private var name: String
    @State private var transportMode: TransportMode
    @State private var isSaving = false

    init(leg: TripLeg, viewModel: TripLegsViewModel, onDismiss: @escaping () -> Void) {
        self.leg = leg
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _name = State(initialValue: leg.name)
        _transportMode = State(initialValue: leg.transportMode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Leg name", text: $name)
                }

                Section("Transport Mode") {
                    Picker("Mode", selection: $transportMode) {
                        Label("Driving", systemImage: "car").tag(TransportMode.driving)
                        Label("Walking", systemImage: "figure.walk").tag(TransportMode.walking)
                        Label("Cycling", systemImage: "bicycle").tag(TransportMode.cycling)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Edit Leg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = trimmedName != leg.name
        let modeChanged = transportMode != leg.transportMode

        Task {
            if nameChanged || modeChanged {
                let success = await viewModel.updateLeg(
                    id: leg.id,
                    name: nameChanged ? trimmedName : nil,
                    transportMode: modeChanged ? transportMode : nil
                )
                isSaving = false
                if success { onDismiss() }
            } else {
                isSaving = false
                onDismiss()
            }
        }
    }
}
