import SwiftUI
import AppKit
import SwiftTerm
import Darwin

#if os(macOS)
/// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView. Runs a shell in the given workspace directory.
struct EmbeddedTerminalView: NSViewRepresentable {
    let workspacePath: String
    /// When true, the terminal view is made first responder so it receives key events (e.g. Control+C).
    var isSelected: Bool = true

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.caretColor = .systemGreen
        view.getTerminal().setCursorStyle(.steadyBlock)
        view.processDelegate = context.coordinator
        view.translatesAutoresizingMaskIntoConstraints = false

        let shell = Self.userShell
        let execName = "-" + (shell as NSString).lastPathComponent
        let dir = (workspacePath as NSString).expandingTildeInPath
        view.startProcess(
            executable: shell,
            args: [],
            environment: nil,
            execName: execName,
            currentDirectory: dir
        )
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        guard isSelected else { return }
        // Make the terminal first responder so it receives key events (Control+C, etc.).
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static var userShell: String {
        let bufsize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufsize > 0 else { return "/bin/zsh" }
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufsize)
        defer { buffer.deallocate() }
        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        guard getpwuid_r(getuid(), &pwd, buffer, bufsize, &result) == 0, result != nil else {
            return "/bin/zsh"
        }
        return String(cString: pwd.pw_shell)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}
#endif
