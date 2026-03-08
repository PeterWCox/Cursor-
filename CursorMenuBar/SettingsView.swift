import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("workspacePath") private var workspacePath: String = FileManager.default.homeDirectoryForCurrentUser.path
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Workspace path:")
                    TextField("~/path/to/repo", text: $workspacePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        selectWorkspaceFolder()
                    }
                }
            } header: {
                Text("Repository")
            } footer: {
                Text("The directory (usually a git repo) where Cursor agent will work. Agent will use .cursor/rules and AGENTS.md from this path.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 120)
    }
    
    private func selectWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if !workspacePath.isEmpty && FileManager.default.fileExists(atPath: workspacePath) {
            panel.directoryURL = URL(fileURLWithPath: workspacePath)
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            workspacePath = url.path
        }
    }
}
