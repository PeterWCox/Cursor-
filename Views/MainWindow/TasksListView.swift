import SwiftUI

// MARK: - Tasks (todos) list for a project

struct TasksListView: View {
    let workspacePath: String
    /// Send task content to a new agent; when taskID is non-nil, the new agent is linked to that task.
    var onSendToAgent: (String, UUID?) -> Void
    var onDismiss: () -> Void
    /// Agents for this workspace (for "Link to Agent" menu).
    var agentsForWorkspace: [AgentTab] = []
    var isTaskLinked: (UUID) -> Bool = { _ in false }
    var onLinkTaskToAgent: (ProjectTask, AgentTab) -> Void = { _, _ in }
    var onUnlinkTask: (UUID) -> Void = { _ in }

    @State private var tasks: [ProjectTask] = []
    @State private var editingTask: ProjectTask?
    @State private var editingDraft: String = ""
    @State private var showNewTaskSheet: Bool = false
    @State private var newTaskDraft: String = ""

    private func reloadTasks() {
        tasks = ProjectTasksStorage.tasks(workspacePath: workspacePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(CursorTheme.border)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if tasks.isEmpty && !showNewTaskSheet {
                        emptyState
                    } else {
                        ForEach(tasks) { task in
                            TaskRowView(
                                task: task,
                                isLinked: isTaskLinked(task.id),
                                agentsForWorkspace: agentsForWorkspace,
                                onTap: {
                                    editingDraft = task.content
                                    editingTask = task
                                },
                                onToggleComplete: {
                                    ProjectTasksStorage.updateTask(workspacePath: workspacePath, id: task.id, completed: !task.completed)
                                    reloadTasks()
                                },
                                onSendToAgent: { onSendToAgent(task.content, task.id) },
                                onLinkToAgent: { agent in onLinkTaskToAgent(task, agent) },
                                onUnlink: { onUnlinkTask(task.id) },
                                onDelete: {
                                    ProjectTasksStorage.deleteTask(workspacePath: workspacePath, id: task.id)
                                    reloadTasks()
                                }
                            )
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reloadTasks() }
        .sheet(isPresented: $showNewTaskSheet) {
            newTaskSheet
        }
        .sheet(item: $editingTask) { task in
            editTaskSheet(task: task)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CursorTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tasks")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CursorTheme.textPrimary)
                Text((workspacePath as NSString).lastPathComponent)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CursorTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                newTaskDraft = ""
                showNewTaskSheet = true
            }) {
                Label("New task", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CursorTheme.brandBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(CursorTheme.textTertiary)
                .symbolRenderingMode(.hierarchical)
            Text("No tasks yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CursorTheme.textSecondary)
            Text("Add a task to track work for this project. You can send any task to a new agent tab.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(CursorTheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Button(action: {
                newTaskDraft = ""
                showNewTaskSheet = true
            }) {
                Label("New task", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(CursorTheme.brandBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var newTaskSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New task")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CursorTheme.textPrimary)
                Spacer()
                Button("Cancel") {
                    showNewTaskSheet = false
                }
                .foregroundStyle(CursorTheme.textSecondary)
                Button("Add") {
                    let trimmed = newTaskDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        _ = ProjectTasksStorage.addTask(workspacePath: workspacePath, content: trimmed)
                        reloadTasks()
                        showNewTaskSheet = false
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(CursorTheme.brandBlue)
                .disabled(newTaskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            Divider().background(CursorTheme.border)
            TextEditor(text: $newTaskDraft)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .foregroundStyle(CursorTheme.textPrimary)
                .padding(12)
                .frame(minHeight: 160)
        }
        .frame(width: 420, height: 280)
        .background(CursorTheme.surface)
    }

    @ViewBuilder
    private func editTaskSheet(task: ProjectTask) -> some View {
        EditTaskSheet(
            initialContent: task.content,
            onSave: { newContent in
                let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    ProjectTasksStorage.updateTask(workspacePath: workspacePath, id: task.id, content: trimmed)
                    reloadTasks()
                }
                editingTask = nil
            },
            onCancel: { editingTask = nil }
        )
    }
}

// MARK: - Task row

private struct TaskRowView: View {
    let task: ProjectTask
    let isLinked: Bool
    let agentsForWorkspace: [AgentTab]
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onSendToAgent: () -> Void
    let onLinkToAgent: (AgentTab) -> Void
    let onUnlink: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggleComplete) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.completed ? CursorTheme.brandBlue : CursorTheme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                Text(task.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(task.completed ? CursorTheme.textTertiary : CursorTheme.textPrimary)
                    .strikethrough(task.completed)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Send to new Agent", systemImage: "bubble.left.and.bubble.right") {
                    onSendToAgent()
                }
                if !agentsForWorkspace.isEmpty {
                    Menu("Link to Agent", systemImage: "link") {
                        ForEach(agentsForWorkspace) { agent in
                            Button(agent.title) {
                                onLinkToAgent(agent)
                            }
                        }
                    }
                }
                if isLinked {
                    Button("Unlink from Agent", systemImage: "link.slash") {
                        onUnlink()
                    }
                }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(CursorTheme.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(12)
        .background(CursorTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CursorTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Edit task sheet (markdown content)

private struct EditTaskSheet: View {
    let initialContent: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit task")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CursorTheme.textPrimary)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .foregroundStyle(CursorTheme.textSecondary)
                Button("Save") {
                    onSave(draft)
                }
                .fontWeight(.semibold)
                .foregroundStyle(CursorTheme.brandBlue)
            }
            .padding(16)
            Divider().background(CursorTheme.border)
            TextEditor(text: $draft)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .foregroundStyle(CursorTheme.textPrimary)
                .padding(12)
                .frame(minHeight: 200)
        }
        .frame(width: 440, height: 320)
        .background(CursorTheme.surface)
        .onAppear { draft = initialContent }
    }
}
