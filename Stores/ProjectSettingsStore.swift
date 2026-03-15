import Foundation
import Combine

struct ProjectSettingsSnapshot: Equatable {
    var debugURL: String
    var startupScriptContents: String

    static let empty = ProjectSettingsSnapshot(debugURL: "", startupScriptContents: "")
}

@MainActor
final class ProjectSettingsStore: ObservableObject {
    @Published private var snapshotsByWorkspace: [String: ProjectSettingsSnapshot] = [:]

    private var changeObserver: NSObjectProtocol?

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: ProjectSettingsStorage.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let workspacePath = notification.userInfo?["workspacePath"] as? String else { return }
            self?.reload(workspacePath: workspacePath)
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func ensureLoaded(workspacePath: String) {
        let normalizedPath = normalizedWorkspacePath(workspacePath)
        guard snapshotsByWorkspace[normalizedPath] == nil else { return }
        reload(workspacePath: normalizedPath)
    }

    func reload(workspacePath: String) {
        let normalizedPath = normalizedWorkspacePath(workspacePath)
        guard !normalizedPath.isEmpty else { return }
        snapshotsByWorkspace[normalizedPath] = ProjectSettingsSnapshot(
            debugURL: ProjectSettingsStorage.getDebugURL(workspacePath: normalizedPath) ?? "",
            startupScriptContents: ProjectSettingsStorage.getStartupScriptContents(workspacePath: normalizedPath) ?? ""
        )
    }

    func snapshot(for workspacePath: String) -> ProjectSettingsSnapshot {
        ensureLoaded(workspacePath: workspacePath)
        return snapshotsByWorkspace[normalizedWorkspacePath(workspacePath)] ?? .empty
    }

    func debugURL(for workspacePath: String) -> String? {
        let value = snapshot(for: workspacePath).debugURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func startupScriptContents(for workspacePath: String) -> String? {
        let value = snapshot(for: workspacePath).startupScriptContents
        return value.isEmpty ? nil : value
    }

    func setDebugURL(workspacePath: String, _ value: String?) {
        ProjectSettingsStorage.setDebugURL(workspacePath: workspacePath, value)
        reload(workspacePath: workspacePath)
    }

    func setStartupScriptContents(workspacePath: String, _ value: String?) {
        ProjectSettingsStorage.setStartupScriptContents(workspacePath: workspacePath, value)
        reload(workspacePath: workspacePath)
    }

    private func normalizedWorkspacePath(_ workspacePath: String) -> String {
        workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
