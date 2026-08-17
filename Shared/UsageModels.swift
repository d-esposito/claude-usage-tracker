import Foundation

struct UsageSnapshot: Codable, Equatable, Sendable {
    var limits: [UsageLimit]
    var fetchedAt: Date
    var accountLabel: String?

    static let preview = UsageSnapshot(
        limits: [
            UsageLimit(id: "session", title: "5-hour limit", percent: 56, resetsAt: Date().addingTimeInterval(2_700), kind: .session),
            UsageLimit(id: "weekly-all", title: "Weekly · All models", percent: 7, resetsAt: Date().addingTimeInterval(5 * 86_400), kind: .weekly),
            UsageLimit(id: "weekly-fable", title: "Weekly · Fable", percent: 10, resetsAt: Date().addingTimeInterval(5 * 86_400), kind: .model)
        ],
        fetchedAt: Date(),
        accountLabel: "Claude"
    )
}

struct UsageLimit: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case session
        case weekly
        case model
    }

    let id: String
    let title: String
    let percent: Double
    let resetsAt: Date?
    let kind: Kind

    var clampedPercent: Double { min(max(percent, 0), 100) }
    var remainingPercent: Double { 100 - clampedPercent }
}

struct ClaudeUsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: Date?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    struct ModernLimit: Decodable {
        struct Scope: Decodable {
            struct Model: Decodable {
                let displayName: String?

                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                }
            }

            let model: Model?
        }

        let kind: String
        let percent: Double
        let resetsAt: Date?
        let scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind
            case percent
            case resetsAt = "resets_at"
            case scope
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDaySonnet: Window?
    let sevenDayOpus: Window?
    let limits: [ModernLimit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case limits
    }

    func snapshot(at date: Date = Date()) -> UsageSnapshot {
        let modern = (limits ?? []).compactMap { limit -> UsageLimit? in
            switch limit.kind {
            case "session":
                return UsageLimit(id: "session", title: "5-hour limit", percent: limit.percent, resetsAt: limit.resetsAt, kind: .session)
            case "weekly_all":
                return UsageLimit(id: "weekly-all", title: "Weekly · All models", percent: limit.percent, resetsAt: limit.resetsAt, kind: .weekly)
            case "weekly_scoped":
                let name = limit.scope?.model?.displayName ?? "Model"
                return UsageLimit(id: "weekly-\(name.lowercased())", title: "Weekly · \(name)", percent: limit.percent, resetsAt: limit.resetsAt, kind: .model)
            default:
                return nil
            }
        }

        if !modern.isEmpty {
            return UsageSnapshot(limits: modern, fetchedAt: date, accountLabel: "Claude")
        }

        var legacy: [UsageLimit] = []
        if let fiveHour, let utilization = fiveHour.utilization {
            legacy.append(UsageLimit(id: "session", title: "5-hour limit", percent: utilization, resetsAt: fiveHour.resetsAt, kind: .session))
        }
        if let sevenDay, let utilization = sevenDay.utilization {
            legacy.append(UsageLimit(id: "weekly-all", title: "Weekly · All models", percent: utilization, resetsAt: sevenDay.resetsAt, kind: .weekly))
        }
        if let window = sevenDaySonnet, let utilization = window.utilization {
            legacy.append(UsageLimit(id: "weekly-sonnet", title: "Weekly · Sonnet", percent: utilization, resetsAt: window.resetsAt, kind: .model))
        } else if let window = sevenDayOpus, let utilization = window.utilization {
            legacy.append(UsageLimit(id: "weekly-opus", title: "Weekly · Opus", percent: utilization, resetsAt: window.resetsAt, kind: .model))
        }
        return UsageSnapshot(limits: legacy, fetchedAt: date, accountLabel: "Claude")
    }
}

extension JSONDecoder {
    static var claudeUsage: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return decoder
    }
}
