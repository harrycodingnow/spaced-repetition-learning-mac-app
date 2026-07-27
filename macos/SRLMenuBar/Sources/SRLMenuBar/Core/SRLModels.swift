import Foundation

struct Attempt: Codable, Equatable, Sendable {
    let rating: Int
    let date: String
}

struct ProblemRecord: Codable, Equatable, Sendable {
    var history: [Attempt]
    var url: String?

    init(history: [Attempt] = [], url: String? = nil) {
        self.history = history
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case history
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        history = try container.decodeIfPresent([Attempt].self, forKey: .history) ?? []
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }
}

struct NextUpRecord: Codable, Equatable, Sendable {
    var added: String?
    var url: String?
    var order: Int?

    init(added: String? = nil, url: String? = nil, order: Int? = nil) {
        self.added = added
        self.url = url
        self.order = order
    }
}

struct AuditAttempt: Codable, Equatable, Sendable {
    var date: String?
    var problem: String?
    var result: String?
}

struct AuditStore: Codable, Equatable, Sendable {
    var currentAudit: String?
    var history: [AuditAttempt]

    init(currentAudit: String? = nil, history: [AuditAttempt] = []) {
        self.currentAudit = currentAudit
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case currentAudit = "current_audit"
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentAudit = try container.decodeIfPresent(String.self, forKey: .currentAudit)
        history = try container.decodeIfPresent([AuditAttempt].self, forKey: .history) ?? []
    }
}

struct SRLSnapshot: Equatable, Sendable {
    var inProgress: [String: ProblemRecord]
    var mastered: [String: ProblemRecord]
    var nextUp: [String: NextUpRecord]
    var audit: AuditStore

    static let empty = SRLSnapshot(
        inProgress: [:],
        mastered: [:],
        nextUp: [:],
        audit: AuditStore()
    )
}

struct PracticeProblem: Identifiable, Equatable, Sendable {
    let name: String
    let url: String?
    let lastRating: Int?
    let lastAttempt: Date?
    let dueDate: Date?

    var id: String { name.lowercased() }
}

struct ActivityQuestionSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let url: String?
    let attemptCount: Int
}

struct RouteProblem: Identifiable, Equatable, Sendable {
    let routeIndex: Int
    let category: String
    let name: String
    let url: String

    var id: Int { routeIndex }
}

struct RecordResult: Equatable, Sendable {
    let problemName: String
    let mastered: Bool
    let message: String
}

enum SRLDay {
    static func parse(_ value: String, calendar: Calendar = .current) -> Date? {
        let datePart = value.prefix(10)
        let pieces = datePart.split(separator: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2])
        else {
            return nil
        }

        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else {
            return nil
        }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }

        return date
    }

    static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
