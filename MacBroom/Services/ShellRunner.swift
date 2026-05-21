import Foundation

enum ShellRunner {
    struct Result {
        let success: Bool
        let output: String
        let errorMessage: String?
    }

    /// Run a shell command. If `requiresAdmin`, uses AppleScript "with administrator
    /// privileges" so macOS pops the auth dialog.
    static func run(_ command: String, requiresAdmin: Bool = false) async -> Result {
        if requiresAdmin {
            return await runWithAdmin(command)
        }
        return await runDirect(command)
    }

    private static func runDirect(_ command: String) async -> Result {
        await withCheckedContinuation { (continuation: CheckedContinuation<Result, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.launchPath = "/bin/zsh"
                process.arguments = ["-c", command]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError  = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let success = process.terminationStatus == 0
                    continuation.resume(returning: Result(
                        success: success, output: output,
                        errorMessage: success ? nil : "Exit \(process.terminationStatus)"
                    ))
                } catch {
                    continuation.resume(returning: Result(
                        success: false, output: "",
                        errorMessage: error.localizedDescription
                    ))
                }
            }
        }
    }

    private static func runWithAdmin(_ command: String) async -> Result {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        do shell script "\(escaped)" with administrator privileges
        """
        return await withCheckedContinuation { (continuation: CheckedContinuation<Result, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var errorInfo: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let nsResult = appleScript?.executeAndReturnError(&errorInfo)
                if let info = errorInfo {
                    let message = info[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
                    continuation.resume(returning: Result(success: false, output: "", errorMessage: message))
                } else {
                    let output = nsResult?.stringValue ?? ""
                    continuation.resume(returning: Result(success: true, output: output, errorMessage: nil))
                }
            }
        }
    }
}
