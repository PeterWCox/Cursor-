import Foundation

// MARK: - Per-project tasks (todos)
// Stored in .cursormetro/tasks.json; only tasks for the current project are shown in that project's Tasks view.

struct ProjectTask: Identifiable, Codable, Equatable {
    var id: UUID
    var content: String
    var createdAt: Date
    var completed: Bool

    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), completed: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.completed = completed
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

    static func addTask(workspacePath: String, content: String) -> ProjectTask {
        var file = load(workspacePath: workspacePath)
        let task = ProjectTask(content: content)
        file.tasks.append(task)
        save(workspacePath: workspacePath, file)
        return task
    }

    static func updateTask(workspacePath: String, id: UUID, content: String? = nil, completed: Bool? = nil) {
        var file = load(workspacePath: workspacePath)
        guard let index = file.tasks.firstIndex(where: { $0.id == id }) else { return }
        if let content = content { file.tasks[index].content = content }
        if let completed = completed { file.tasks[index].completed = completed }
        save(workspacePath: workspacePath, file)
    }

    static func deleteTask(workspacePath: String, id: UUID) {
        var file = load(workspacePath: workspacePath)
        file.tasks.removeAll { $0.id == id }
        save(workspacePath: workspacePath, file)
    }
}
