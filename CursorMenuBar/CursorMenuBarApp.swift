import SwiftUI
import AppKit

@main
struct CursorMenuBarApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("Cursor Quick Prompt", systemImage: "bubble.left.and.bubble.right.fill") {
            PopoutView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @AppStorage("workspacePath") var workspacePath: String = FileManager.default.homeDirectoryForCurrentUser.path
    
    var workspaceDisplayName: String {
        guard !workspacePath.isEmpty else { return "" }
        let url = URL(fileURLWithPath: workspacePath)
        if workspacePath == FileManager.default.homeDirectoryForCurrentUser.path {
            return "~/"
        }
        return url.lastPathComponent.isEmpty ? url.deletingLastPathComponent().lastPathComponent : url.lastPathComponent
    }
    
    func changeWorkspace() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.title = "Select Workspace"
            panel.message = "Choose the repository directory where Cursor agent will work."
            
            if !self.workspacePath.isEmpty && FileManager.default.fileExists(atPath: self.workspacePath) {
                panel.directoryURL = URL(fileURLWithPath: self.workspacePath)
            } else {
                panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            }
            
            if panel.runModal() == .OK, let url = panel.url {
                self.workspacePath = url.path
            }
        }
    }
}
