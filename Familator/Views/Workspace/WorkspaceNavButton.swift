import SwiftUI

struct WorkspaceNavButton: View {
    @EnvironmentObject var workspaceVM: WorkspaceViewModel

    var body: some View {
        Button {
            workspaceVM.showWorkspacePicker = true
        } label: {
            HStack(spacing: 4) {
                Text(workspaceVM.activeWorkspace?.name ?? "Workspace")
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }
}
