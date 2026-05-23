import SwiftUI

struct WorkspaceSwitcherSheet: View {
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @EnvironmentObject var auth: AuthService

    var body: some View {
        NavigationStack {
            List(workspaceVM.workspaces) { workspace in
                Button {
                    if let userId = auth.currentUser?.id {
                        workspaceVM.setActiveWorkspace(workspace, userId: userId)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: workspace.color) ?? .indigo)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text(workspace.code)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workspace.name)
                                .font(.body)
                            if workspace.isPersonal {
                                Text("Personal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if workspace.id == workspaceVM.activeWorkspace?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        workspaceVM.showWorkspacePicker = false
                    }
                }
            }
        }
    }
}

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let intVal = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
