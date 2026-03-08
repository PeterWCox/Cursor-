import Foundation

enum AgentRunnerError: Error {
    case agentNotFound
    case notAuthenticated
    case processFailed(exitCode: Int32, stderr: String)
    
    var userMessage: String {
        switch self {
        case .agentNotFound:
            return "Cursor CLI not found. Install with: curl https://cursor.com/install -fsSL | bash\n\nEnsure ~/.local/bin is in your PATH."
        case .notAuthenticated:
            return "Not authenticated. Run 'agent login' in Terminal first."
        case .processFailed(let code, let stderr):
            var msg = "Agent exited with code \(code)."
            if !stderr.isEmpty {
                msg += "\n\n\(stderr)"
            }
            if stderr.contains("login") || stderr.contains("auth") || stderr.contains("authenticate") {
                msg += "\n\nTry running 'agent login' in Terminal."
            }
            return msg
        }
    }
}

@MainActor
final class AgentRunner {
    static func run(prompt: String, workspacePath: String) async throws -> String {
        guard let agentPath = findAgentPath() else {
            throw AgentRunnerError.agentNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: agentPath)
        process.arguments = [
            "-f",
            "-p", prompt,
            "--workspace", workspacePath
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
        
        let env = ProcessInfo.processInfo.environment
        var fullEnv = env
        if let path = env["PATH"], !path.contains(".local/bin") {
            let home = env["HOME"] ?? NSHomeDirectory()
            fullEnv["PATH"] = "\(home)/.local/bin:\(path)"
        }
        process.environment = fullEnv
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        
        process.launch()
        
        let stdoutData = stdoutHandle.readDataToEndOfFile()
        let stderrData = stderrHandle.readDataToEndOfFile()
        process.waitUntilExit()
        
        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            throw AgentRunnerError.processFailed(exitCode: process.terminationStatus, stderr: stderrStr)
        }
        
        return stdoutStr
    }
    
    private static func findAgentPath() -> String? {
        let pathsToCheck = [
            "\(NSHomeDirectory())/.local/bin/agent",
            "/usr/local/bin/agent",
            "/opt/homebrew/bin/agent"
        ]
        
        for path in pathsToCheck {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for component in path.split(separator: ":") {
                let candidate = "\(component)/agent"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        
        return nil
    }
}
