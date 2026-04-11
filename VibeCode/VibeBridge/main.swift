import Foundation
import Shared

/// VibeBridge: CLI tool invoked by Claude Code hooks
/// Reads hook event JSON from stdin, relays to VibeCode app via Unix socket
/// For permission requests, blocks until user responds

// Parse command line args
var source = "claude"
for (i, arg) in CommandLine.arguments.enumerated() {
    if arg == "--source", i + 1 < CommandLine.arguments.count {
        source = CommandLine.arguments[i + 1]
    }
}

// Read stdin
let inputData = FileHandle.standardInput.readDataToEndOfFile()
guard !inputData.isEmpty else { exit(0) }

// Parse hook event
guard let (eventType, hookInput) = EventParser.parse(data: inputData) else {
    fputs("Failed to parse hook input\n", stderr)
    exit(1)
}

let sessionId = hookInput.sessionId ?? "unknown"
let messageId = UUID().uuidString

// Get the TTY by walking up the process tree (bridge → shell → claude)
// The bridge is spawned by a shell, which is spawned by claude. We need claude's TTY.
var ttyPath: String? = nil
do {
    let ppid = getppid()
    let pipe = Pipe()
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/bin/ps")
    // Get PPID and TTY of our parent (the shell), so we can find its parent (claude)
    proc.arguments = ["-o", "ppid=,tty=", "-p", "\(ppid)"]
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    try proc.run()
    proc.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let parts = output.split(separator: " ", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }

    if parts.count >= 2, parts[1] != "??", !parts[1].isEmpty {
        // Shell itself has a TTY
        ttyPath = parts[1]
    } else if parts.count >= 1, let grandparentPid = Int(parts[0]) {
        // Shell has no TTY, look up grandparent (claude process)
        let pipe2 = Pipe()
        let proc2 = Process()
        proc2.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc2.arguments = ["-o", "tty=", "-p", "\(grandparentPid)"]
        proc2.standardOutput = pipe2
        proc2.standardError = FileHandle.nullDevice
        try proc2.run()
        proc2.waitUntilExit()
        let ttyStr = String(data: pipe2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ttyStr.isEmpty, ttyStr != "??" {
            ttyPath = ttyStr
        }
    }
}

// Build IPC message
let message = IPCMessage(
    id: messageId,
    eventType: eventType,
    source: source,
    sessionId: sessionId,
    cwd: hookInput.cwd,
    toolName: hookInput.toolName,
    toolInput: hookInput.toolInput,
    prompt: hookInput.prompt,
    transcriptPath: hookInput.transcriptPath,
    tty: ttyPath,
    timestamp: Date().timeIntervalSince1970
)

guard let messageData = try? JSONEncoder().encode(message) else {
    fputs("Failed to encode message\n", stderr)
    exit(1)
}

// Connect to VibeCode app
let socketPath = "/tmp/vibecode.sock"
let client = SocketClient(path: socketPath)

do {
    try client.connect()
    try client.sendMessage(messageData)
    fputs("[vibecode-bridge] sent \(eventType.rawValue) for session \(sessionId)\n", stderr)
} catch {
    fputs("[vibecode-bridge] socket error: \(error)\n", stderr)
    client.close()
    exit(0)
}

// For permission requests, wait for response
if eventType == .permissionRequest {
    do {
        let responseData = try client.readResponse(timeout: 86400)
        // Parse response manually to work around Swift compiler bug
        guard let responseJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let decision = responseJson["decision"] as? String else {
            exit(2)
        }

        // Check if response contains updatedInput (for AskUserQuestion)
        let updatedInput = responseJson["updatedInput"] as? [String: Any]

        // Debug log
        fputs("[vibecode-bridge] response: \(responseJson)\n", stderr)
        if let ui = updatedInput {
            fputs("[vibecode-bridge] updatedInput: \(ui)\n", stderr)
        }

        // Map our decision format to Claude Code's expected format
        let behavior: String
        switch decision {
        case "allow", "always_allow":
            behavior = "allow"
        case "deny", "always_deny":
            behavior = "deny"
        default:
            behavior = "deny"
        }

        // Format response as Claude Code expects
        var decisionDict: [String: Any] = ["behavior": behavior]
        if let updatedInput = updatedInput {
            decisionDict["updatedInput"] = updatedInput
        }

        let hookOutput: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decisionDict
            ]
        ]
        if let outputData = try? JSONSerialization.data(withJSONObject: hookOutput) {
            fputs("[vibecode-bridge] output: \(String(data: outputData, encoding: .utf8) ?? "nil")\n", stderr)
            FileHandle.standardOutput.write(outputData)
        }
    } catch {
        // Timeout or error — let Claude Code handle it
        client.close()
        exit(2)
    }
} else {
    // For non-permission events, close and exit immediately
    client.close()
    exit(0)
}

client.close()
