type Root = {
    settings: {
        models: string[];
    }
    projects: {
        name: string;
        tasks: {
            name: string;
            taskId: string;
        }
        conversations: {
            name: string;
            taskId: string;
        }
    }[]
}

// --- Corrected (how the app actually works) ---
// Root is split: AppState (settings, global state) + TabManager (projects, agents).
// Projects are keyed by path; "name" is derived (e.g. last path component), not stored.
// Each project has: many tasks (in .metro/tasks.json) and many agents (AgentTab;
// agents are the conversations). Agents are stored globally in TabManager and associated
// to a project by workspacePath. Some agents are linked to a task via linkedTaskID.

type Root_actual = {
    // AppState: models at app level; other prefs in UserDefaults
    settings: {
        models: string[];  // AppState.availableModels
    };
    // TabManager.projects: list keyed by path; no stored "name"
    projects: {
        path: string;      // ProjectState.path (id = path); display name from path
        tasks: {
            name: string;  // ProjectTask.content
            taskId: string; // ProjectTask.id (UUID)
        }[];
        agents: {
            name: string;       // AgentTab.title
            taskId: string | null;  // AgentTab.linkedTaskID — only some agents are linked to a task
        }[];
    }[];
}
