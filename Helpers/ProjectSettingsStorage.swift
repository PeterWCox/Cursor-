import Foundation

// MARK: - Per-project settings (debug URL, startup script)
// Stored in .metro/project.json (like Cursor uses .cursor)

private struct ProjectSettingsFile: Codable {
    var debugUrl: String?
    /// Deprecated: startup script is now stored in .metro/startup.sh. Kept for decoding old project.json.
    var startupScript: String?
    /// Instructions for the agent when debugging (e.g. "when the terminal is opened" context). Used when creating a debug agent from Preview.
    var debugInstructions: String?
}

enum ProjectSettingsStorage {
    static let didChangeNotification = Notification.Name("ProjectSettingsStorageDidChange")
    private static var cachedSettingsByWorkspace: [String: ProjectSettingsFile] = [:]
    private static var cachedStartupScriptsByWorkspace: [String: String?] = [:]

    private static func normalizedWorkspacePath(_ workspacePath: String) -> String {
        workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func projectSettingsURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".metro")
            .appendingPathComponent("project.json")
    }

    /// Legacy path for migration from .cursor/project-settings.json
    private static func legacyProjectSettingsURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".cursor")
            .appendingPathComponent("project-settings.json")
    }

    private static func load(workspacePath: String) -> ProjectSettingsFile {
        let normalizedPath = normalizedWorkspacePath(workspacePath)
        if let cached = cachedSettingsByWorkspace[normalizedPath] {
            return cached
        }

        migrateCursormetroToMetroIfNeeded(workspacePath: workspacePath)
        let url = projectSettingsURL(workspacePath: workspacePath)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(ProjectSettingsFile.self, from: data) {
            cachedSettingsByWorkspace[normalizedPath] = decoded
            return decoded
        }
        // Migrate from legacy .cursor/project-settings.json
        let legacyURL = legacyProjectSettingsURL(workspacePath: workspacePath)
        if let data = try? Data(contentsOf: legacyURL),
           let legacy = try? JSONDecoder().decode(ProjectSettingsFile.self, from: data) {
            save(workspacePath: workspacePath, legacy)
            return legacy
        }
        let empty = ProjectSettingsFile(debugUrl: nil, startupScript: nil, debugInstructions: nil)
        cachedSettingsByWorkspace[normalizedPath] = empty
        return empty
    }

    private static func save(workspacePath: String, _ file: ProjectSettingsFile) {
        let url = projectSettingsURL(workspacePath: workspacePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: url)
        let normalizedPath = normalizedWorkspacePath(workspacePath)
        cachedSettingsByWorkspace[normalizedPath] = file
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: ["workspacePath": normalizedPath]
        )
    }

    // MARK: - Debug URL (View in Browser)

    static func getDebugURL(workspacePath: String) -> String? {
        let trimmed = load(workspacePath: workspacePath).debugUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func setDebugURL(workspacePath: String, _ value: String?) {
        var existing = load(workspacePath: workspacePath)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        existing.debugUrl = trimmed?.isEmpty == false ? trimmed : nil
        save(workspacePath: workspacePath, existing)
    }

    // MARK: - Startup script (.metro/startup.sh; run with bash)

    /// URL of the fixed startup script file (`.metro/startup.sh`).
    static func startupScriptFileURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".metro")
            .appendingPathComponent("startup.sh")
    }

    /// Reads the contents of `.metro/startup.sh`. Returns nil if file does not exist.
    static func getStartupScriptContents(workspacePath: String) -> String? {
        let normalizedPath = normalizedWorkspacePath(workspacePath)
        if let cached = cachedStartupScriptsByWorkspace[normalizedPath] {
            return cached
        }

        let url = startupScriptFileURL(workspacePath: workspacePath)
        guard let data = try? Data(contentsOf: url) else {
            cachedStartupScriptsByWorkspace[normalizedPath] = nil
            return nil
        }
        let contents = String(data: data, encoding: .utf8)
        cachedStartupScriptsByWorkspace[normalizedPath] = contents
        return contents
    }

    /// Writes the contents of `.metro/startup.sh`. Creates `.metro` directory if needed.
    static func setStartupScriptContents(workspacePath: String, _ value: String?) {
        let url = startupScriptFileURL(workspacePath: workspacePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = value ?? ""
        try? content.write(to: url, atomically: true, encoding: .utf8)
        let normalizedPath = normalizedWorkspacePath(workspacePath)
        cachedStartupScriptsByWorkspace[normalizedPath] = content
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: ["workspacePath": normalizedPath]
        )
    }

    // MARK: - Debug instructions (prefilled when creating debug agent from Preview)

    static func getDebugInstructions(workspacePath: String) -> String? {
        let trimmed = load(workspacePath: workspacePath).debugInstructions?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func setDebugInstructions(workspacePath: String, _ value: String?) {
        var existing = load(workspacePath: workspacePath)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        existing.debugInstructions = trimmed?.isEmpty == false ? trimmed : nil
        save(workspacePath: workspacePath, existing)
    }
}
