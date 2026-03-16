import Foundation

enum AgentProviderID: String, Codable, CaseIterable, Identifiable {
    case cursor
    case claudeCode = "claude-code"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor:
            return "Cursor"
        case .claudeCode:
            return "Claude"
        }
    }
}

struct AgentProviderDescriptor {
    let id: AgentProviderID
    let displayName: String
    let defaultModelID: String
    let fallbackModels: [ModelOption]
    let defaultEnabledModelIds: Set<String>
    let defaultShownModelIds: Set<String>
}

struct AgentStreamRequest {
    let prompt: String
    let workspacePath: String
    let modelID: String?
    let conversationID: String?
}

protocol AgentProvider {
    var descriptor: AgentProviderDescriptor { get }
    func createConversation() throws -> String
    func listModels() async throws -> [ModelOption]
    func stream(request: AgentStreamRequest) throws -> AsyncThrowingStream<AgentStreamChunk, Error>
}

enum AgentProviders {
    static let defaultProviderID: AgentProviderID = .cursor

    static func provider(for id: AgentProviderID) -> any AgentProvider {
        switch id {
        case .cursor:
            CursorAgentProvider.shared
        case .claudeCode:
            ClaudeCodeAgentProvider.shared
        }
    }

    static func resolvedProviderID(_ rawValue: String) -> AgentProviderID {
        AgentProviderID(rawValue: rawValue) ?? defaultProviderID
    }

    static func descriptor(for id: AgentProviderID) -> AgentProviderDescriptor {
        provider(for: id).descriptor
    }

    static func defaultModelID(for id: AgentProviderID) -> String {
        descriptor(for: id).defaultModelID
    }

    static func fallbackModels(for id: AgentProviderID) -> [ModelOption] {
        descriptor(for: id).fallbackModels
    }

    static func defaultEnabledModelIds(for id: AgentProviderID) -> Set<String> {
        descriptor(for: id).defaultEnabledModelIds
    }

    static func defaultShownModelIds(for id: AgentProviderID) -> Set<String> {
        descriptor(for: id).defaultShownModelIds
    }
}

private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .array(let values):
            let rendered = values.compactMap(\.stringValue)
            return rendered.isEmpty ? nil : rendered.joined(separator: ", ")
        case .object:
            return nil
        case .null:
            return nil
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let object) = self {
            return object
        }
        return nil
    }
}

private struct UnavailableAgentProvider: AgentProvider {
    let id: AgentProviderID

    var descriptor: AgentProviderDescriptor {
        AgentProviderDescriptor(
            id: id,
            displayName: id.displayName,
            defaultModelID: "auto",
            fallbackModels: [
                ModelOption(id: "auto", label: "Auto", isPremium: false)
            ],
            defaultEnabledModelIds: ["auto"],
            defaultShownModelIds: ["auto"]
        )
    }

    func createConversation() throws -> String {
        throw AgentProviderError.providerUnavailable(id)
    }

    func listModels() async throws -> [ModelOption] {
        throw AgentProviderError.providerUnavailable(id)
    }

    func stream(request: AgentStreamRequest) throws -> AsyncThrowingStream<AgentStreamChunk, Error> {
        throw AgentProviderError.providerUnavailable(id)
    }
}

// MARK: - Stream JSON event types (Cursor CLI stream-json format)
private struct StreamEvent: Decodable {
    let type: String?
    let subtype: String?
    let text: String?
    let message: StreamMessage?
    let callID: String?
    let toolCall: StreamToolCallPayload?

    private enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case text
        case message
        case callID = "call_id"
        case toolCall = "tool_call"
    }
}

private struct StreamMessage: Decodable {
    let content: [StreamContent]?
}

private struct StreamContent: Decodable {
    let type: String?
    let text: String?
}

private struct StreamToolCallPayload: Decodable {
    let toolName: String
    let description: String?
    let args: StreamToolCallArgs?
    let result: StreamToolCallResult?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        guard let key = container.allKeys.first,
              let invocation = try container.decodeIfPresent(StreamToolInvocation.self, forKey: key) else {
            toolName = "Tool"
            description = nil
            args = nil
            result = nil
            return
        }

        toolName = Self.displayName(for: key.stringValue)
        description = invocation.description
        args = invocation.args
        result = invocation.result
    }

    private static func displayName(for rawName: String) -> String {
        let trimmed = rawName.replacingOccurrences(of: "ToolCall", with: "")
        let separated = trimmed.replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return separated
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct StreamToolInvocation: Decodable {
    let description: String?
    let args: StreamToolCallArgs?
    let result: StreamToolCallResult?
}

private struct StreamToolCallArgs: Decodable {
    let command: String?
    let path: String?
    let globPattern: String?
    let pattern: String?
    let query: String?
    let url: String?
    let workingDirectory: String?
    let description: String?
}

private struct StreamToolCallResult: Decodable {
    let success: StreamToolCallSuccess?
    let failure: StreamToolCallFailure?
    let error: StreamToolCallFailure?
}

private struct StreamToolCallSuccess: Decodable {
    let exitCode: Int?
    let executionTime: Int?
    let localExecutionTimeMs: Int?
    let durationMs: Int?
}

private struct StreamToolCallFailure: Decodable {
    let exitCode: Int?
    let stderr: String?
    let message: String?
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

enum AgentStreamChunk {
    case conversationIDUpdated(String)
    case thinkingDelta(String)
    case thinkingCompleted
    case assistantText(String)
    case toolCall(AgentToolCallUpdate)
}

enum AgentToolCallStatus {
    case started
    case completed
    case failed
}

struct AgentToolCallUpdate {
    let callID: String
    let title: String
    let detail: String
    let status: AgentToolCallStatus
}

enum AgentProviderError: Error {
    case providerUnavailable(AgentProviderID)
    case agentNotFound
    case notAuthenticated
    case processFailed(exitCode: Int32, stderr: String)
    
    var userMessage: String {
        switch self {
        case .providerUnavailable(let providerID):
            return "\(providerID.displayName) integration is not available yet."
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
                msg += "\n\nTry signing in with the selected provider CLI and then run the request again."
            }
            return msg
        }
    }
}

private enum ClaudeCodeModels {
    static let sonnetID = "sonnet"
    static let opusID = "opus"

    static let fallback: [ModelOption] = [
        ModelOption(id: sonnetID, label: "Sonnet", isPremium: false),
        ModelOption(id: opusID, label: "Opus", isPremium: true)
    ]

    static let defaultEnabledModelIds: Set<String> = [sonnetID, opusID]
    static let defaultShownModelIds: Set<String> = [sonnetID, opusID]
}

final class CursorAgentProvider: AgentProvider {
    static let shared = CursorAgentProvider()

    let descriptor = AgentProviderDescriptor(
        id: .cursor,
        displayName: AgentProviderID.cursor.displayName,
        defaultModelID: AvailableModels.autoID,
        fallbackModels: AvailableModels.fallback,
        defaultEnabledModelIds: AvailableModels.defaultEnabledModelIds,
        defaultShownModelIds: AvailableModels.defaultShownModelIds
    )

    private init() {}

    /// Creates a new Cursor CLI chat and returns its ID. Use this before the first message in a tab so follow-ups can use `--resume`.
    func createConversation() throws -> String {
        guard let agentPath = Self.findAgentPath() else {
            throw AgentProviderError.agentNotFound
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: agentPath)
        process.arguments = ["create-chat"]
        let env = ProcessInfo.processInfo.environment
        var fullEnv = env
        if let path = env["PATH"], !path.contains(".local/bin") {
            let home = env["HOME"] ?? NSHomeDirectory()
            fullEnv["PATH"] = "\(home)/.local/bin:\(path)"
        }
        process.environment = fullEnv
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AgentProviderError.processFailed(exitCode: process.terminationStatus, stderr: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let id = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .newlines)
        guard let id = id, !id.isEmpty else {
            throw AgentProviderError.processFailed(exitCode: -1, stderr: "create-chat did not return a chat ID")
        }
        return id
    }

    /// Fetches available models from the Cursor Agent CLI (`agent models`). Call from a background context.
    func listModels() async throws -> [ModelOption] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.runListModelsSync()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func runListModelsSync() throws -> [ModelOption] {
        guard let agentPath = findAgentPath() else {
            throw AgentProviderError.agentNotFound
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: agentPath)
        process.arguments = ["models"]
        let env = ProcessInfo.processInfo.environment
        var fullEnv = env
        if let path = env["PATH"], !path.contains(".local/bin") {
            let home = env["HOME"] ?? NSHomeDirectory()
            fullEnv["PATH"] = "\(home)/.local/bin:\(path)"
        }
        process.environment = fullEnv
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AgentProviderError.processFailed(exitCode: process.terminationStatus, stderr: "")
        }
        guard let output = String(data: data, encoding: .utf8) else {
            throw AgentProviderError.processFailed(exitCode: -1, stderr: "Could not decode agent models output")
        }
        return Self.parseModelsOutput(output)
    }

    /// Parses `agent models` stdout: lines like "id - Label" or "id - Label  (current)".
    nonisolated private static func parseModelsOutput(_ output: String) -> [ModelOption] {
        let knownPremiumIds: Set<String> = [
            "gpt-5.4-medium", "gpt-5.4-high", "gpt-5.4-xhigh", "gpt-5.4-medium-fast", "gpt-5.4-high-fast", "gpt-5.4-xhigh-fast",
            "composer-1.5", "composer-1",
            "opus-4.6", "opus-4.6-thinking", "opus-4.5", "opus-4.5-thinking",
            "sonnet-4.6", "sonnet-4.6-thinking", "sonnet-4.5", "sonnet-4.5-thinking",
        ]
        func stripANSI(_ s: String) -> String {
            let pattern = "\\x1B\\[[0-9;]*[a-zA-Z]"
            return s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        var result: [ModelOption] = []
        for line in output.components(separatedBy: .newlines) {
            let cleaned = stripANSI(line).trimmingCharacters(in: .whitespaces)
            guard cleaned.contains(" - ") else { continue }
            if cleaned.hasPrefix("Available models") || cleaned.hasPrefix("Loading") || cleaned.hasPrefix("Tip:") {
                continue
            }
            guard let dashRange = cleaned.range(of: " - ") else { continue }
            let id = String(cleaned[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var label = String(cleaned[dashRange.upperBound...])
                .replacingOccurrences(of: "  (current)", with: "")
                .replacingOccurrences(of: "  (default)", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty, !label.isEmpty else { continue }
            result.append(ModelOption(
                id: id,
                label: label,
                isPremium: knownPremiumIds.contains(id)
            ))
        }
        return result
    }

    func stream(request: AgentStreamRequest) throws -> AsyncThrowingStream<AgentStreamChunk, Error> {
        guard let agentPath = Self.findAgentPath() else {
            throw AgentProviderError.agentNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: agentPath)
        var args = [
            "-f",
            "-p", request.prompt,
            "--workspace", request.workspacePath,
            "--output-format", "stream-json",
            "--stream-partial-output"
        ]
        if let conversationId = request.conversationID, !conversationId.isEmpty {
            args += ["--resume", conversationId]
        }
        if let model = request.modelID, !model.isEmpty {
            args += ["--model", model]
        }
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: projectRootForTerminal(workspacePath: request.workspacePath))
        
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
        
        try process.run()
        
        return AsyncThrowingStream { continuation in
            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
            }
            
            Task.detached {
                let stderrTask = Task.detached { () -> String in
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    return String(data: data, encoding: .utf8) ?? ""
                }
                
                let handle = stdoutPipe.fileHandleForReading
                let decoder = JSONDecoder()
                var lineBuffer = ""
                var streamComplete = false
                
                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    
                    guard let chunk = String(data: data, encoding: .utf8) else { continue }
                    lineBuffer += chunk
                    
                    while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
                        let line = String(lineBuffer[..<newlineIndex])
                        lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])
                        
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { continue }
                        
                        do {
                            let event = try decoder.decode(StreamEvent.self, from: Data(trimmed.utf8))
                            
                            if event.type == "result" {
                                streamComplete = true
                                break
                            }

                            if event.type == "thinking" {
                                if event.subtype == "delta", let text = event.text, !text.isEmpty {
                                    continuation.yield(.thinkingDelta(text))
                                } else if event.subtype == "completed" {
                                    continuation.yield(.thinkingCompleted)
                                }
                                continue
                            }

                            if let toolCallUpdate = Self.toolCallUpdate(from: event) {
                                continuation.yield(.toolCall(toolCallUpdate))
                                continue
                            }

                            if event.type == "assistant", let message = event.message, let content = message.content {
                                for item in content {
                                    if item.type == "text", let text = item.text, !text.isEmpty {
                                        continuation.yield(.assistantText(text))
                                    }
                                }
                            }
                        } catch {
                            // Skip malformed JSON lines
                            continue
                        }
                    }
                    
                    if streamComplete { break }
                }
                
                process.waitUntilExit()
                let stderrStr = await stderrTask.value
                
                if process.terminationStatus != 0 {
                    continuation.finish(throwing: AgentProviderError.processFailed(
                        exitCode: process.terminationStatus, stderr: stderrStr))
                } else {
                    continuation.finish()
                }
            }
        }
    }
    
    nonisolated private static func findAgentPath() -> String? {
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

    nonisolated private static func toolCallUpdate(from event: StreamEvent) -> AgentToolCallUpdate? {
        guard event.type == "tool_call",
              let subtype = event.subtype,
              let callID = event.callID,
              let toolCall = event.toolCall else {
            return nil
        }

        let title = nonEmpty(toolCall.description) ?? toolCall.toolName
        let baseDetail = toolCallBaseDetail(for: toolCall)

        switch subtype {
        case "started":
            return AgentToolCallUpdate(
                callID: callID,
                title: title,
                detail: baseDetail,
                status: .started
            )
        case "completed":
            return AgentToolCallUpdate(
                callID: callID,
                title: title,
                detail: toolCallCompletionDetail(base: baseDetail, result: toolCall.result),
                status: toolCallStatus(for: toolCall.result)
            )
        default:
            return nil
        }
    }

    nonisolated private static func toolCallBaseDetail(for toolCall: StreamToolCallPayload) -> String {
        guard let args = toolCall.args else { return "" }

        let candidates = [
            nonEmpty(singleLine(args.command)),
            nonEmpty(args.path),
            nonEmpty(args.globPattern),
            nonEmpty(singleLine(args.pattern)),
            nonEmpty(singleLine(args.query)),
            nonEmpty(singleLine(args.url)),
            nonEmpty(args.workingDirectory),
            nonEmpty(singleLine(args.description))
        ]

        return candidates.compactMap { $0 }.first ?? ""
    }

    nonisolated private static func toolCallCompletionDetail(base: String, result: StreamToolCallResult?) -> String {
        var parts: [String] = []
        if let detail = nonEmpty(base) {
            parts.append(detail)
        }

        if let failure = result?.failure ?? result?.error {
            if let exitCode = failure.exitCode {
                parts.append("exit \(exitCode)")
            }
            if let message = nonEmpty(singleLine(failure.message ?? failure.stderr)) {
                parts.append(message)
            }
            return parts.joined(separator: " | ")
        }

        if let success = result?.success {
            if let exitCode = success.exitCode, exitCode != 0 {
                parts.append("exit \(exitCode)")
            }
            if let duration = toolCallDuration(from: success) {
                parts.append(duration)
            }
        }

        return parts.joined(separator: " | ")
    }

    nonisolated private static func toolCallStatus(for result: StreamToolCallResult?) -> AgentToolCallStatus {
        if result?.failure != nil || result?.error != nil {
            return .failed
        }

        if let exitCode = result?.success?.exitCode, exitCode != 0 {
            return .failed
        }

        return .completed
    }

    nonisolated private static func toolCallDuration(from success: StreamToolCallSuccess) -> String? {
        let durationMs = success.localExecutionTimeMs ?? success.executionTime ?? success.durationMs
        guard let durationMs else { return nil }

        if durationMs >= 1000 {
            return String(format: "%.1fs", Double(durationMs) / 1000)
        }

        return "\(durationMs)ms"
    }

    nonisolated private static func singleLine(_ text: String?) -> String? {
        text?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}

private struct ClaudeStreamEnvelope: Decodable {
    let type: String
    let subtype: String?
    let sessionID: String?
    let isError: Bool?
    let result: String?
    let error: String?
    let message: ClaudeStreamMessage?
    let event: ClaudeStreamEventPayload?

    private enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case sessionID = "session_id"
        case isError = "is_error"
        case result
        case error
        case message
        case event
    }
}

private struct ClaudeStreamMessage: Decodable {
    let id: String?
    let role: String?
    let content: [ClaudeStreamContentBlock]
}

private struct ClaudeStreamContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: JSONValue?
    let toolUseID: String?
    let content: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case toolUseID = "tool_use_id"
        case content
    }
}

private struct ClaudeStreamEventPayload: Decodable {
    let type: String
    let delta: ClaudeStreamDelta?
}

private struct ClaudeStreamDelta: Decodable {
    let type: String?
    let text: String?
    let thinking: String?
}

final class ClaudeCodeAgentProvider: AgentProvider {
    static let shared = ClaudeCodeAgentProvider()

    let descriptor = AgentProviderDescriptor(
        id: .claudeCode,
        displayName: AgentProviderID.claudeCode.displayName,
        defaultModelID: ClaudeCodeModels.sonnetID,
        fallbackModels: ClaudeCodeModels.fallback,
        defaultEnabledModelIds: ClaudeCodeModels.defaultEnabledModelIds,
        defaultShownModelIds: ClaudeCodeModels.defaultShownModelIds
    )

    private init() {}

    func createConversation() throws -> String {
        UUID().uuidString.lowercased()
    }

    func listModels() async throws -> [ModelOption] {
        descriptor.fallbackModels
    }

    func stream(request: AgentStreamRequest) throws -> AsyncThrowingStream<AgentStreamChunk, Error> {
        guard let claudePath = Self.findClaudePath() else {
            throw AgentProviderError.processFailed(
                exitCode: -1,
                stderr: "Claude Code CLI not found. Install Claude Code and ensure `claude` is in your PATH."
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)

        let workspaceRoot = projectRootForTerminal(workspacePath: request.workspacePath)
        let screenshotURLs = Self.screenshotURLs(for: request)
        let prompt = Self.promptForRequest(request, screenshotURLs: screenshotURLs)

        let conversationID = request.conversationID?.trimmingCharacters(in: .whitespacesAndNewlines)
        var args = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--dangerously-skip-permissions"
        ]
        if let conversationID, !conversationID.isEmpty {
            args += ["--resume", conversationID]
        } else {
            args += ["--session-id", UUID().uuidString.lowercased()]
        }
        if let model = request.modelID, !model.isEmpty {
            args += ["--model", model]
        }
        for directory in Self.additionalDirectories(for: screenshotURLs, workspaceRoot: workspaceRoot) {
            args += ["--add-dir", directory]
        }
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: workspaceRoot)
        process.environment = Self.commandEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        return AsyncThrowingStream { continuation in
            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
            }

            Task.detached {
                let stderrTask = Task.detached { () -> String in
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    return String(data: data, encoding: .utf8) ?? ""
                }

                let handle = stdoutPipe.fileHandleForReading
                let decoder = JSONDecoder()
                var lineBuffer = ""
                var streamError: AgentProviderError?
                var toolCalls: [String: AgentToolCallUpdate] = [:]
                var latestSessionID: String?

                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }

                    guard let chunk = String(data: data, encoding: .utf8) else { continue }
                    lineBuffer += chunk

                    while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
                        let line = String(lineBuffer[..<newlineIndex])
                        lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }

                        do {
                            let event = try decoder.decode(ClaudeStreamEnvelope.self, from: Data(trimmed.utf8))
                            if let sessionID = event.sessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !sessionID.isEmpty,
                               sessionID != latestSessionID {
                                latestSessionID = sessionID
                                continuation.yield(.conversationIDUpdated(sessionID))
                            }

                            switch event.type {
                            case "stream_event":
                                if let delta = event.event?.delta {
                                    if delta.type == "text_delta", let text = delta.text, !text.isEmpty {
                                        continuation.yield(.assistantText(text))
                                    } else if delta.type == "thinking_delta",
                                              let text = delta.thinking ?? delta.text,
                                              !text.isEmpty {
                                        continuation.yield(.thinkingDelta(text))
                                    }
                                }
                            case "assistant":
                                guard let message = event.message else { continue }
                                for block in message.content {
                                    if block.type == "tool_use",
                                       let callID = block.id,
                                       let name = block.name {
                                        let update = AgentToolCallUpdate(
                                            callID: callID,
                                            title: name,
                                            detail: Self.toolDetail(from: block.input),
                                            status: .started
                                        )
                                        toolCalls[callID] = update
                                        continuation.yield(.toolCall(update))
                                    } else if block.type == "text",
                                              let text = block.text,
                                              !text.isEmpty {
                                        continuation.yield(.assistantText(text))
                                    }
                                }
                            case "user":
                                guard let message = event.message else { continue }
                                for block in message.content where block.type == "tool_result" {
                                    guard let callID = block.toolUseID else { continue }
                                    let existing = toolCalls[callID]
                                    let update = AgentToolCallUpdate(
                                        callID: callID,
                                        title: existing?.title ?? "Tool",
                                        detail: Self.toolResultDetail(from: block.content) ?? existing?.detail ?? "",
                                        status: .completed
                                    )
                                    toolCalls[callID] = update
                                    continuation.yield(.toolCall(update))
                                }
                            case "result":
                                if event.isError == true || event.subtype == "error" {
                                    let message = event.error ?? event.result ?? "Claude Code request failed."
                                    streamError = .processFailed(exitCode: -1, stderr: message)
                                }
                            default:
                                continue
                            }
                        } catch {
                            continue
                        }
                    }
                }

                process.waitUntilExit()
                let stderr = await stderrTask.value

                if let streamError {
                    continuation.finish(throwing: streamError)
                } else if process.terminationStatus != 0 {
                    continuation.finish(throwing: AgentProviderError.processFailed(
                        exitCode: process.terminationStatus,
                        stderr: stderr
                    ))
                } else {
                    continuation.finish()
                }
            }
        }
    }

    private static func promptForRequest(_ request: AgentStreamRequest, screenshotURLs: [URL]) -> String {
        guard !screenshotURLs.isEmpty else { return request.prompt }
        let renderedPaths = screenshotURLs.map(\.path).joined(separator: "\n- ")
        return """
\(request.prompt)

The screenshot references in this prompt point to local image files. Open and inspect the actual image files directly when they are relevant:
- \(renderedPaths)
"""
    }

    private static func screenshotURLs(for request: AgentStreamRequest) -> [URL] {
        screenshotPaths(from: request.prompt).map {
            screenshotFileURL(path: $0, workspacePath: request.workspacePath)
        }
    }

    private static func additionalDirectories(for screenshotURLs: [URL], workspaceRoot: String) -> [String] {
        let root = URL(fileURLWithPath: workspaceRoot).standardizedFileURL.path
        var result: [String] = []
        for directory in screenshotURLs.map({ $0.deletingLastPathComponent().standardizedFileURL.path }) {
            guard directory != root,
                  !directory.hasPrefix(root + "/"),
                  !result.contains(directory) else { continue }
            result.append(directory)
        }
        return result
    }

    private static func toolDetail(from input: JSONValue?) -> String {
        guard let object = input?.objectValue else { return "" }
        let preferredKeys = [
            "command",
            "path",
            "file_path",
            "glob",
            "pattern",
            "query",
            "url",
            "description",
            "prompt"
        ]
        for key in preferredKeys {
            if let value = object[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value.replacingOccurrences(of: "\n", with: " ")
            }
        }
        return ""
    }

    private static func toolResultDetail(from content: JSONValue?) -> String? {
        switch content {
        case .some(.string(let value)):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed.replacingOccurrences(of: "\n", with: " ")
        case .some(.array(let values)):
            let text = values.compactMap { value -> String? in
                guard case .object(let object) = value,
                      object["type"]?.stringValue == "text",
                      let rendered = object["text"]?.stringValue else { return nil }
                let trimmed = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }.joined(separator: " ")
            return text.isEmpty ? nil : text.replacingOccurrences(of: "\n", with: " ")
        default:
            return nil
        }
    }

    private static func findClaudePath() -> String? {
        findExecutable(named: "claude")
    }

    private static func commandEnvironment() -> [String: String] {
        let env = ProcessInfo.processInfo.environment
        var fullEnv = env
        if let path = env["PATH"], !path.contains(".local/bin") {
            let home = env["HOME"] ?? NSHomeDirectory()
            fullEnv["PATH"] = "\(home)/.local/bin:\(path)"
        }
        return fullEnv
    }
}

private func findExecutable(named executable: String) -> String? {
    let pathsToCheck = [
        "\(NSHomeDirectory())/.local/bin/\(executable)",
        "/usr/local/bin/\(executable)",
        "/opt/homebrew/bin/\(executable)"
    ]

    for path in pathsToCheck {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }

    if let path = ProcessInfo.processInfo.environment["PATH"] {
        for component in path.split(separator: ":") {
            let candidate = "\(component)/\(executable)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
    }

    return nil
}
