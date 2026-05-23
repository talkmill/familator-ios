import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var workspaceVM: WorkspaceViewModel

    var body: some View {
        TabView {
            TripsView()
                .tabItem {
                    Label("Trips", systemImage: "airplane")
                }
            WorkView()
                .tabItem {
                    Label("Work", systemImage: "checklist")
                }
            NavigationStack {
                CurrentListView()
            }
            .tabItem {
                Label("Current", systemImage: "bolt.fill")
            }
            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .sheet(isPresented: $workspaceVM.showWorkspacePicker) {
            WorkspaceSwitcherSheet()
        }
    }
}
