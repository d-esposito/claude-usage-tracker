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
    static let label = "io.github.d-esposito.ClaudeUsageTrackerDesktop"
    private static let legacyLabels = ["local.davidesposito.ClaudeUsageTrackerDesktop"]

    private var agentURL: URL {
        agentURL(for: Self.label)
    }

    private var legacyAgentURLs: [URL] {
        Self.legacyLabels.map(agentURL(for:))
    }

    var isEnabled: Bool {
        ([agentURL] + legacyAgentURLs).contains {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

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
            removeLegacyAgents(from: domain)
            _ = runLaunchctl(["bootout", domain, agentURL.path])
            guard runLaunchctl(["bootstrap", domain, agentURL.path]) == 0 else {
                throw LaunchAtLoginError.launchctlFailed
            }
        } else {
            _ = runLaunchctl(["bootout", domain, agentURL.path])
            try? FileManager.default.removeItem(at: agentURL)
            removeLegacyAgents(from: domain)
        }
    }

    private func agentURL(for label: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private func removeLegacyAgents(from domain: String) {
        for url in legacyAgentURLs {
            _ = runLaunchctl(["bootout", domain, url.path])
            try? FileManager.default.removeItem(at: url)
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
