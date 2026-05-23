import SwiftUI

struct PlaceSearchView: View {
    @ObservedObject var viewModel: TripPlacesViewModel
    let onDismiss: () -> Void

    @State private var manualName = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isGoogleSearchAvailable {
                    TextField("Search places…", text: $viewModel.searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                        .onChange(of: viewModel.searchQuery) { newValue in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                guard !Task.isCancelled else { return }
                                await viewModel.searchPlaces(query: newValue)
                            }
                        }

                    if viewModel.isSearching {
                        ProgressView()
                            .padding()
                    }

                    List {
                        ForEach(viewModel.suggestions) { suggestion in
                            Button {
                                Task {
                                    await viewModel.addPlace(from: suggestion)
                                    viewModel.searchQuery = ""
                                    viewModel.suggestions = []
                                    onDismiss()
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(suggestion.displayName)
                                    if let address = suggestion.formattedAddress {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                Task {
                                    await viewModel.addPlaceByName(viewModel.searchQuery)
                                    viewModel.searchQuery = ""
                                    viewModel.suggestions = []
                                    onDismiss()
                                }
                            } label: {
                                Label("Add \"\(viewModel.searchQuery)\" as text", systemImage: "plus.circle")
                            }
                        }
                    }
                } else {
                    TextField("Place name", text: $manualName)
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    Button("Add Place") {
                        Task {
                            await viewModel.addPlaceByName(manualName)
                            manualName = ""
                            onDismiss()
                        }
                    }
                    .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}
