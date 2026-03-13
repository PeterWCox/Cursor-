import Foundation
import AppKit

// MARK: - Per-project tasks (todos)
// Stored in .cursormetro/tasks.json; only tasks for the current project are shown in that project's Tasks view.

struct ProjectTask: Identifiable, Codable, Equatable {
    var id: UUID
    var content: String
    var createdAt: Date
    var completed: Bool
    /// When the task was marked completed; nil if not completed or completed before this field existed.
    var completedAt: Date?
    /// Relative paths under .cursormetro (e.g. "screenshots/<id>_0.png") for task screenshots. Empty = no screenshots.
    var screenshotPaths: [String]

    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), completed: Bool = false, completedAt: Date? = nil, screenshotPaths: [String] = []) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.completed = completed
        self.completedAt = completedAt
        self.screenshotPaths = screenshotPaths
    }

    enum CodingKeys: String, CodingKey {
        case id, content, createdAt, completed, completedAt, screenshotPath, screenshotPaths
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        completed = try c.decode(Bool.self, forKey: .completed)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        if let paths = try c.decodeIfPresent([String].self, forKey: .screenshotPaths) {
            screenshotPaths = paths
        } else if let single = try c.decodeIfPresent(String.self, forKey: .screenshotPath) {
            screenshotPaths = [single]
        } else {
            screenshotPaths = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(completed, forKey: .completed)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(screenshotPaths, forKey: .screenshotPaths)
    }
}

private struct ProjectTasksFile: Codable {
    var tasks: [ProjectTask]
}

enum ProjectTasksStorage {
    static func tasksURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".cursormetro")
            .appendingPathComponent("tasks.json")
    }

    /// Directory for task screenshots: .cursormetro/screenshots/
    static func screenshotsDirectoryURL(workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".cursormetro")
            .appendingPathComponent("screenshots", isDirectory: true)
    }

    /// Full file URL for a task's screenshot. Pass screenshotPath from the task (e.g. "screenshots/<id>.png").
    static func taskScreenshotFileURL(workspacePath: String, screenshotPath: String) -> URL {
        URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".cursormetro")
            .appendingPathComponent(screenshotPath)
    }

    private static func load(workspacePath: String) -> ProjectTasksFile {
        let url = tasksURL(workspacePath: workspacePath)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(ProjectTasksFile.self, from: data) {
            return decoded
        }
        return ProjectTasksFile(tasks: [])
    }

    private static func save(workspacePath: String, _ file: ProjectTasksFile) {
        let url = tasksURL(workspacePath: workspacePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: url)
    }

    static func tasks(workspacePath: String) -> [ProjectTask] {
        load(workspacePath: workspacePath).tasks.sorted { $0.createdAt < $1.createdAt }
    }

    static func addTask(workspacePath: String, content: String, screenshotImages: [NSImage] = []) -> ProjectTask {
        var file = load(workspacePath: workspacePath)
        var task = ProjectTask(content: content)
        let dir = screenshotsDirectoryURL(workspacePath: workspacePath)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for (index, image) in screenshotImages.enumerated() {
            let relPath = "screenshots/\(task.id.uuidString)_\(index).png"
            let fileURL = dir.appendingPathComponent("\(task.id.uuidString)_\(index).png")
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: fileURL)
                paths.append(relPath)
            }
        }
        task.screenshotPaths = paths
        file.tasks.append(task)
        save(workspacePath: workspacePath, file)
        return task
    }

    static func updateTask(workspacePath: String, id: UUID, content: String? = nil, completed: Bool? = nil) {
        var file = load(workspacePath: workspacePath)
        guard let index = file.tasks.firstIndex(where: { $0.id == id }) else { return }
        if let content = content { file.tasks[index].content = content }
        if let completed = completed {
            file.tasks[index].completed = completed
            file.tasks[index].completedAt = completed ? Date() : nil
        }
        save(workspacePath: workspacePath, file)
    }

    /// Update the task's screenshots: save images to .cursormetro/screenshots/<id>_0.png, _1.png, etc.; remove any old files not in the new set.
    static func updateTaskScreenshots(workspacePath: String, id: UUID, images: [NSImage]) {
        var file = load(workspacePath: workspacePath)
        guard let index = file.tasks.firstIndex(where: { $0.id == id }) else { return }
        let dir = screenshotsDirectoryURL(workspacePath: workspacePath)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let oldPaths = file.tasks[index].screenshotPaths
        var newPaths: [String] = []
        for (i, img) in images.enumerated() {
            let relPath = "screenshots/\(id.uuidString)_\(i).png"
            let fileURL = dir.appendingPathComponent("\(id.uuidString)_\(i).png")
            if let tiff = img.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: fileURL)
                newPaths.append(relPath)
            }
        }
        for oldPath in oldPaths where !newPaths.contains(oldPath) {
            let url = taskScreenshotFileURL(workspacePath: workspacePath, screenshotPath: oldPath)
            try? FileManager.default.removeItem(at: url)
        }
        file.tasks[index].screenshotPaths = newPaths
        save(workspacePath: workspacePath, file)
    }

    /// Remove one screenshot by path and delete its file.
    static func removeTaskScreenshot(workspacePath: String, id: UUID, screenshotPath: String) {
        var file = load(workspacePath: workspacePath)
        guard let index = file.tasks.firstIndex(where: { $0.id == id }) else { return }
        file.tasks[index].screenshotPaths.removeAll { $0 == screenshotPath }
        let url = taskScreenshotFileURL(workspacePath: workspacePath, screenshotPath: screenshotPath)
        try? FileManager.default.removeItem(at: url)
        save(workspacePath: workspacePath, file)
    }

    static func deleteTask(workspacePath: String, id: UUID) {
        var file = load(workspacePath: workspacePath)
        guard let index = file.tasks.firstIndex(where: { $0.id == id }) else { return }
        for path in file.tasks[index].screenshotPaths {
            let url = taskScreenshotFileURL(workspacePath: workspacePath, screenshotPath: path)
            try? FileManager.default.removeItem(at: url)
        }
        file.tasks.removeAll { $0.id == id }
        save(workspacePath: workspacePath, file)
    }
}
