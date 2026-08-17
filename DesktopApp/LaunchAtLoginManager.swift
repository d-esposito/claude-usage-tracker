import Foundation

enum LaunchAtLoginError: LocalizedError {
    case executableMissing
    case launchctlFailed

    var errorDescription: String? {
        switch self {
        case .executableMissing: "The app executable could not be located."
        case .launchctlFailed: "macOS could not update the login item."
        }
    }
}

struct LaunchAtLoginManager {
    static let label = "local.davidesposito.ClaudeUsageTrackerDesktop"

    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    var isEnabled: Bool { FileManager.default.fileExists(atPath: agentURL.path) }

    func setEnabled(_ enabled: Bool) throws {
        let domain = "gui/\(getuid())"
        if enabled {
            guard let executable = Bundle.main.executableURL else { throw LaunchAtLoginError.executableMissing }
            let directory = agentURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let propertyList: [String: Any] = [
                "Label": Self.label,
                "ProgramArguments": [executable.path],
                "RunAtLoad": true
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: propertyList, format: .xml, options: 0)
            try data.write(to: agentURL, options: .atomic)
            _ = runLaunchctl(["bootout", domain, agentURL.path])
            guard runLaunchctl(["bootstrap", domain, agentURL.path]) == 0 else {
                throw LaunchAtLoginError.launchctlFailed
            }
        } else {
            _ = runLaunchctl(["bootout", domain, agentURL.path])
            try? FileManager.default.removeItem(at: agentURL)
        }
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
