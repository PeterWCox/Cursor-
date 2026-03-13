import Foundation

// MARK: - Per-project settings (debug URL, startup script)
// Stored in .cursormetro/project.json (like Cursor uses .cursor)

private struct ProjectSettingsFile: Codable {
    var debugUrl: String?
    var startupScript: String?
}

enum ProjectSettingsStorage {
    static func projectSettingsURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".cursormetro")
            .appendingPathComponent("project.json")
    }

    /// Legacy path for migration from .cursor/project-settings.json
    private static func legacyProjectSettingsURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".cursor")
            .appendingPathComponent("project-settings.json")
    }

    private static func load(workspacePath: String) -> ProjectSettingsFile {
        let url = projectSettingsURL(workspacePath: workspacePath)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(ProjectSettingsFile.self, from: data) {
            return decoded
        }
        // Migrate from legacy .cursor/project-settings.json
        let legacyURL = legacyProjectSettingsURL(workspacePath: workspacePath)
        if let data = try? Data(contentsOf: legacyURL),
           let legacy = try? JSONDecoder().decode(ProjectSettingsFile.self, from: data) {
            save(workspacePath: workspacePath, legacy)
            return legacy
        }
        return ProjectSettingsFile(debugUrl: nil, startupScript: nil)
    }

    private static func save(workspacePath: String, _ file: ProjectSettingsFile) {
        let url = projectSettingsURL(workspacePath: workspacePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: url)
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

    // MARK: - Startup script (path relative to workspace or absolute; run with bash)

    static func getStartupScript(workspacePath: String) -> String? {
        let trimmed = load(workspacePath: workspacePath).startupScript?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func setStartupScript(workspacePath: String, _ value: String?) {
        var existing = load(workspacePath: workspacePath)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        existing.startupScript = trimmed?.isEmpty == false ? trimmed : nil
        save(workspacePath: workspacePath, existing)
    }
}
