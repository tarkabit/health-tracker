import Foundation

enum ClaudeCLIError: LocalizedError {
    case notFound
    case nonZeroExit(code: Int32, stderr: String)
    case timedOut
    case badOutput(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Couldn't find the `claude` command. Install Claude Code and sign in once (run `claude` in Terminal), or set its path with HEALTH_TRACKER_CLAUDE."
        case .nonZeroExit(let code, let stderr):
            return "claude exited with code \(code).\n\(stderr.isEmpty ? "(no output)" : stderr)"
        case .timedOut:
            return "claude took too long to respond and was stopped."
        case .badOutput(let s):
            return "Couldn't read claude's response.\n\(s.prefix(400))"
        case .apiError(let s):
            return "claude returned an error: \(s)"
        }
    }
}

/// Runs the `claude` CLI headlessly (one-shot, no tools) using the user's logged-in
/// Pro/Max **subscription** — text in, text out, no API key required.
///
/// Invocation verified against Claude Code 2.1.187:
///   claude -p --output-format json --tools "" --permission-mode dontAsk \
///          --append-system-prompt <system> <prompt>
/// `--tools ""` + `--permission-mode dontAsk` guarantee zero tool use and no permission
/// prompt, so the subprocess can never hang waiting on a TTY. The assistant's final text
/// is the `result` field of the JSON envelope. (Never pass `--bare` — it forces API-key auth.)
struct ClaudeCLI {

    let binaryPath: String?

    init(binaryPath: String? = ClaudeCLI.resolveBinary()) {
        self.binaryPath = binaryPath
    }

    var isAvailable: Bool { binaryPath != nil }

    // MARK: Binary resolution (GUI launches from Finder inherit a minimal PATH)

    static func resolveBinary() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            ProcessInfo.processInfo.environment["HEALTH_TRACKER_CLAUDE"],
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
        ].compactMap { $0 }

        for path in candidates where fm.isExecutableFile(atPath: path) { return path }
        return whichViaLoginShell()
    }

    /// Last resort: ask a login shell where `claude` lives (picks up the user's real PATH).
    private static func whichViaLoginShell() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", "command -v claude"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    // MARK: Run

    /// Run a single prompt with an appended system prompt; returns the assistant's final text.
    ///
    /// `imagePaths` (absolute file paths) enables vision: the `Read` tool is allowed, scoped
    /// to each image's folder, and the paths are appended to the prompt so the model reads them.
    /// With no images the call is pure text in/out with all tools disabled.
    func run(prompt: String,
             system: String,
             imagePaths: [String] = [],
             timeout: TimeInterval = 120) async throws -> String {
        guard let bin = binaryPath else { throw ClaudeCLIError.notFound }

        var fullPrompt = prompt
        if !imagePaths.isEmpty {
            fullPrompt += "\n\nIMAGES — read each of these with the Read tool and use them as input:\n"
            fullPrompt += imagePaths.joined(separator: "\n")
        }

        var args = ["-p", "--output-format", "json", "--permission-mode", "dontAsk"]
        if imagePaths.isEmpty {
            args += ["--tools", ""]                      // no tools — pure text in/out
        } else {
            args += ["--allowedTools", "Read"]           // vision: read the screenshot only
            for dir in Set(imagePaths.map { ($0 as NSString).deletingLastPathComponent }) {
                args += ["--add-dir", dir]
            }
        }
        args += ["--append-system-prompt", system, fullPrompt]

        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: bin)
                proc.arguments = args

                let out = Pipe()
                let err = Pipe()
                proc.standardOutput = out
                proc.standardError = err

                do { try proc.run() } catch {
                    cont.resume(throwing: ClaudeCLIError.notFound)
                    return
                }

                // Watchdog: terminate if the model never returns.
                var timedOut = false
                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    if proc.isRunning { timedOut = true; proc.terminate() }
                }
                timer.resume()

                // Drain both pipes concurrently to avoid a full-buffer deadlock.
                var outData = Data()
                var errData = Data()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave()
                }
                group.enter()
                DispatchQueue.global().async {
                    errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave()
                }
                proc.waitUntilExit()
                group.wait()
                timer.cancel()

                if timedOut { cont.resume(throwing: ClaudeCLIError.timedOut); return }

                let stderr = String(data: errData, encoding: .utf8) ?? ""
                guard proc.terminationStatus == 0 else {
                    cont.resume(throwing: ClaudeCLIError.nonZeroExit(code: proc.terminationStatus, stderr: stderr))
                    return
                }
                guard let obj = try? JSONSerialization.jsonObject(with: outData) as? [String: Any] else {
                    cont.resume(throwing: ClaudeCLIError.badOutput(String(data: outData, encoding: .utf8) ?? ""))
                    return
                }
                if let isErr = obj["is_error"] as? Bool, isErr {
                    let msg = (obj["result"] as? String)
                        ?? (obj["api_error_status"] as? String)
                        ?? "unknown error"
                    cont.resume(throwing: ClaudeCLIError.apiError(msg))
                    return
                }
                guard let result = obj["result"] as? String else {
                    cont.resume(throwing: ClaudeCLIError.badOutput(String(data: outData, encoding: .utf8) ?? ""))
                    return
                }
                cont.resume(returning: result)
            }
        }
    }
}
