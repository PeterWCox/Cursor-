import SwiftUI
import AppKit

@main
struct CursorMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: FloatingPanel!
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: "Cursor Quick Prompt")
            button.action = #selector(togglePanel)
            button.target = self
        }

        panel = FloatingPanel()
        let hostingView = NSHostingView(
            rootView: PopoutView(dismiss: { [weak self] in
                self?.panel.orderOut(nil)
            })
            .environmentObject(appState)
        )
        panel.contentView = hostingView
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            positionNearStatusItem()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.perform(Selector(("showSettingsWindow:")), with: nil)
    }

    private func positionNearStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }
        let screenFrame = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(screenFrame)
        let x = screenRect.midX - panel.frame.width / 2
        let y = screenRect.minY - panel.frame.height - 4
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        level = .floating
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
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
