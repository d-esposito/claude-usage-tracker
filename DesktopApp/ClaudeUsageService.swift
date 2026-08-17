import Foundation

enum ClaudeUsageError: LocalizedError, Sendable {
    case credentialsMissing
    case tokenMissing
    case unauthorized
    case rateLimited
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .credentialsMissing:
            "Claude Code credentials were not found. Run `claude auth login` first."
        case .tokenMissing:
            "The Claude Code credential has no access token. Run `claude auth login` again."
        case .unauthorized:
            "Claude's token has expired. Open Claude Code once, then refresh."
        case .rateLimited:
            "Claude temporarily rate-limited usage checks. The last reading is still shown."
        case let .server(code, message):
            "Claude returned HTTP \(code): \(message)"
        }
    }
}

struct ClaudeUsageService: Sendable {
    private struct Credentials: Decodable, Sendable {
        struct OAuth: Decodable, Sendable { let accessToken: String }
        let claudeAiOauth: OAuth?
    }

    private struct Authentication: Sendable {
        let token: String
        let userAgent: String
    }

    func fetch() async throws -> UsageSnapshot {
        let authentication = try await Task.detached(priority: .utility) {
            try Self.authentication()
        }.value

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(authentication.token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue(authentication.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 401 { throw ClaudeUsageError.unauthorized }
            if status == 429 { throw ClaudeUsageError.rateLimited }
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeUsageError.server(status, String(detail.prefix(180)))
        }

        return try JSONDecoder.claudeUsage.decode(ClaudeUsageResponse.self, from: data).snapshot()
    }

    private static func authentication() throws -> Authentication {
        let data = try run("/usr/bin/security", arguments: [
            "find-generic-password", "-s", "Claude Code-credentials", "-w"
        ])
        guard let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            throw ClaudeUsageError.credentialsMissing
        }
        guard let token = credentials.claudeAiOauth?.accessToken, !token.isEmpty else {
            throw ClaudeUsageError.tokenMissing
        }
        return Authentication(token: token, userAgent: claudeUserAgent())
    }

    private static func claudeUserAgent() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            guard let data = try? run(path, arguments: ["--version"]),
                  let output = String(data: data, encoding: .utf8),
                  let version = output.split(separator: " ").first else { continue }
            return "claude-code/\(version)"
        }
        return "claude-code/2.1.233"
    }

    private static func run(_ executable: String, arguments: [String]) throws -> Data {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ClaudeUsageError.credentialsMissing
        }
        return data
    }
}
