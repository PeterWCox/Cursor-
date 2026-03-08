import SwiftUI

@main
struct CursorMenuBarApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("Cursor Quick Prompt", image: "MenuBarIcon") {
            Button("Send to Cursor...") {
                appState.showPopout = true
            }
            Divider()
            Button("Settings...") {
                appState.showSettings = true
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
        
        Window("Send to Cursor", id: "popout") {
            PopoutView()
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 360)
        .commandsRemoved()
        .defaultPosition(.center)
        .keyboardShortcut("p", modifiers: .command)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var showPopout = false {
        didSet {
            if showPopout {
                openPopout()
            }
        }
    }
    @Published var showSettings = false
    
    private func openPopout() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "popout" }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
            }
        }
    }
}
