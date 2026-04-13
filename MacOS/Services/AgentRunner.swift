import Foundation

enum AgentProviderID: String, Codable, CaseIterable, Identifiable {
    case cursor

    var id: String { rawValue }

    var displayName: String { "Claude Code" }
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
    func listModels() async throws -> [ModelOption]
    func stream(request: AgentStreamRequest) throws -> AsyncThrowingStream<AgentStreamChunk, Error>
}

enum AgentProviders {
    static let defaultProviderID: AgentProviderID = .cursor

    static func provider(for id: AgentProviderID) -> any AgentProvider {
        ClaudeCodeAgentProvider.shared
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

// MARK: - Claude Code stream-json payloads

private struct ClaudeStreamEnvelope: Decodable {
    let type: String?
    let subtype: String?
    let sessionID: String?
    let message: ClaudeMessage?
    let event: ClaudeStreamEvent?
    let toolUseResult: ClaudeToolUseResultPayload?

    private enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case sessionID = "session_id"
        case message
        case event
        case toolUseResult = "tool_use_result"
    }
}

private struct ClaudeMessage: Decodable {
    let role: String?
    let content: [ClaudeContentBlock]?
}

private struct ClaudeContentBlock: Decodable {
    let type: String?
    let id: String?
    let name: String?
    let text: String?
    let input: JSONValue?
    let toolUseID: String?
    let content: JSONValue?
    let isError: Bool?

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case text
        case input
        case toolUseID = "tool_use_id"
        case content
        case isError = "is_error"
    }
}

private struct ClaudeStreamEvent: Decodable {
    let type: String?
    let index: Int?
    let contentBlock: ClaudeStreamContentBlock?
    let delta: ClaudeStreamDelta?

    private enum CodingKeys: String, CodingKey {
        case type
        case index
        case contentBlock = "content_block"
        case delta
    }
}

private struct ClaudeStreamContentBlock: Decodable {
    let type: String?
    let id: String?
    let name: String?
}

private struct ClaudeStreamDelta: Decodable {
    let type: String?
    let text: String?
    let partialJSON: String?
    let thinking: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case partialJSON = "partial_json"
        case thinking
    }
}

private struct ClaudeToolUseResultPayload: Decodable {
    let stdout: String?
    let stderr: String?
    let interrupted: Bool?
    let noOutputExpected: Bool?
}

private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    var renderedInline: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded(.towardZero) == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case .object, .array:
            return prettyPrintedJSON ?? ""
        }
    }

    var prettyPrintedJSON: String? {
        guard let object = foundationObject else { return nil }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private var foundationObject: Any? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        case .object(let value):
            return value.mapValues(\.foundationObject)
        case .array(let value):
            return value.map(\.foundationObject)
        }
    }
}

private struct PartialToolUseState {
    let callID: String
    let title: String
    var partialInputJSON: String = ""
    var resolvedDetail: String = ""
}

enum AgentStreamChunk {
    case sessionInitialized(String)
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
    case agentNotFound
    case processFailed(exitCode: Int32, stderr: String)

    var userMessage: String {
        switch self {
        case .agentNotFound:
            return "Claude Code CLI not found. Install the `claude` CLI and ensure it is available on your PATH."
        case .processFailed(let code, let stderr):
            var msg = "Agent exited with code \(code)."
            if !stderr.isEmpty {
                msg += "\n\n\(stderr)"
            }
            if stderr.localizedCaseInsensitiveContains("login")
                || stderr.localizedCaseInsensitiveContains("auth")
                || stderr.localizedCaseInsensitiveContains("authenticate") {
                msg += "\n\nTry signing in to Claude Code in Terminal and then run the request again."
            }
            return msg
        }
    }
}

final class ClaudeCodeAgentProvider: AgentProvider {
    static let shared = ClaudeCodeAgentProvider()

    let descriptor = AgentProviderDescriptor(
        id: .cursor,
        displayName: AgentProviderID.cursor.displayName,
        defaultModelID: AvailableModels.autoID,
        fallbackModels: AvailableModels.fallback,
        defaultEnabledModelIds: AvailableModels.defaultEnabledModelIds,
        defaultShownModelIds: AvailableModels.defaultShownModelIds
    )

    private init() {}

    func listModels() async throws -> [ModelOption] {
        AvailableModels.fallback
    }

    func stream(request: AgentStreamRequest) throws -> AsyncThrowingStream<AgentStreamChunk, Error> {
        guard let claudePath = Self.findClaudePath() else {
            throw AgentProviderError.agentNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)

        var args = [
            "-p", request.prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--permission-mode", "bypassPermissions"
        ]
        if let conversationID = request.conversationID, !conversationID.isEmpty {
            args += ["--resume", conversationID]
        }
        if let model = request.modelID, !model.isEmpty, model != AvailableModels.autoID {
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
        process.standardInput = FileHandle.nullDevice

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
                var activeToolUses: [Int: PartialToolUseState] = [:]

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

                        guard let envelope = try? decoder.decode(ClaudeStreamEnvelope.self, from: Data(trimmed.utf8)) else {
                            continue
                        }

                        if let sessionID = envelope.sessionID, !sessionID.isEmpty {
                            continuation.yield(.sessionInitialized(sessionID))
                        }

                        switch envelope.type {
                        case "stream_event":
                            Self.handleStreamEvent(
                                envelope.event,
                                activeToolUses: &activeToolUses,
                                continuation: continuation
                            )
                        case "user":
                            Self.handleToolResultMessage(
                                envelope,
                                activeToolUses: &activeToolUses,
                                continuation: continuation
                            )
                        default:
                            break
                        }
                    }
                }

                process.waitUntilExit()
                let stderrStr = await stderrTask.value

                if process.terminationStatus != 0 {
                    continuation.finish(throwing: AgentProviderError.processFailed(
                        exitCode: process.terminationStatus,
                        stderr: stderrStr
                    ))
                } else {
                    continuation.finish()
                }
            }
        }
    }

    nonisolated private static func handleStreamEvent(
        _ event: ClaudeStreamEvent?,
        activeToolUses: inout [Int: PartialToolUseState],
        continuation: AsyncThrowingStream<AgentStreamChunk, Error>.Continuation
    ) {
        guard let event else { return }

        switch event.type {
        case "content_block_start":
            guard let index = event.index,
                  event.contentBlock?.type == "tool_use" else { return }

            let callID = event.contentBlock?.id ?? UUID().uuidString
            let title = displayName(forTool: event.contentBlock?.name)
            let state = PartialToolUseState(callID: callID, title: title)
            activeToolUses[index] = state
            continuation.yield(.toolCall(AgentToolCallUpdate(
                callID: callID,
                title: title,
                detail: "",
                status: .started
            )))

        case "content_block_delta":
            guard let delta = event.delta else { return }
            switch delta.type {
            case "text_delta":
                if let text = delta.text, !text.isEmpty {
                    continuation.yield(.assistantText(text))
                }
            case "thinking_delta":
                if let thinking = delta.thinking, !thinking.isEmpty {
                    continuation.yield(.thinkingDelta(thinking))
                }
            case "input_json_delta":
                guard let index = event.index,
                      var state = activeToolUses[index] else { return }
                state.partialInputJSON += delta.partialJSON ?? ""
                state.resolvedDetail = toolInputDetail(fromPartialJSON: state.partialInputJSON)
                activeToolUses[index] = state
                continuation.yield(.toolCall(AgentToolCallUpdate(
                    callID: state.callID,
                    title: state.title,
                    detail: state.resolvedDetail,
                    status: .started
                )))
            default:
                break
            }

        case "content_block_stop":
            if let index = event.index, activeToolUses[index] != nil {
                return
            }
            continuation.yield(.thinkingCompleted)

        default:
            break
        }
    }

    nonisolated private static func handleToolResultMessage(
        _ envelope: ClaudeStreamEnvelope,
        activeToolUses: inout [Int: PartialToolUseState],
        continuation: AsyncThrowingStream<AgentStreamChunk, Error>.Continuation
    ) {
        guard let content = envelope.message?.content else { return }

        for block in content where block.type == "tool_result" {
            guard let callID = nonEmpty(block.toolUseID) else { continue }

            let stateMatch = activeToolUses.first { $0.value.callID == callID }
            let state = stateMatch?.value
            if let index = stateMatch?.key {
                activeToolUses.removeValue(forKey: index)
            }

            let baseDetail = nonEmpty(state?.resolvedDetail)
            let resultDetail = nonEmpty(toolResultDetail(block: block, payload: envelope.toolUseResult))
            let detail = [baseDetail, resultDetail].compactMap { $0 }.joined(separator: " | ")

            continuation.yield(.toolCall(AgentToolCallUpdate(
                callID: callID,
                title: state?.title ?? "Tool",
                detail: detail,
                status: block.isError == true ? .failed : .completed
            )))
        }
    }

    nonisolated private static func toolInputDetail(fromPartialJSON partialJSON: String) -> String {
        let trimmed = partialJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let data = trimmed.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let resolved = toolInputDetail(fromJSONString: jsonString) {
            return resolved
        }

        return singleLine(trimmed) ?? ""
    }

    nonisolated private static func toolInputDetail(fromJSONString jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let preferredKeys = [
            "command",
            "description",
            "path",
            "file_path",
            "glob",
            "pattern",
            "query",
            "url",
            "prompt"
        ]

        for key in preferredKeys {
            if let value = jsonObject[key] as? String, let resolved = nonEmpty(singleLine(value)) {
                return resolved
            }
        }

        if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return nil
    }

    nonisolated private static func toolResultDetail(
        block: ClaudeContentBlock,
        payload: ClaudeToolUseResultPayload?
    ) -> String {
        var parts: [String] = []

        if let stdout = nonEmpty(singleLine(payload?.stdout)), !(payload?.noOutputExpected ?? false) {
            parts.append(stdout)
        }
        if let stderr = nonEmpty(singleLine(payload?.stderr)) {
            parts.append(stderr)
        }
        if payload?.interrupted == true {
            parts.append("interrupted")
        }
        if let content = nonEmpty(singleLine(block.content?.renderedInline)), !parts.contains(content) {
            parts.append(content)
        }

        return parts.joined(separator: " | ")
    }

    nonisolated private static func findClaudePath() -> String? {
        let pathsToCheck = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]

        for path in pathsToCheck {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for component in path.split(separator: ":") {
                let candidate = "\(component)/claude"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }

    nonisolated private static func displayName(forTool rawName: String?) -> String {
        guard let rawName = nonEmpty(rawName) else { return "Tool" }
        let separated = rawName.replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return separated
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
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
