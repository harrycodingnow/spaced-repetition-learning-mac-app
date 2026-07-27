import Foundation

enum SRLScheduler {
    static func dueProblems(
        in snapshot: SRLSnapshot,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> [PracticeProblem] {
        let today = calendar.startOfDay(for: date)

        return scheduledProblems(in: snapshot, calendar: calendar)
            .filter { problem in
                guard let dueDate = problem.dueDate else { return false }
                return dueDate <= today
            }
            .sorted { lhs, rhs in
                let lhsAttempt = lhs.lastAttempt ?? .distantPast
                let rhsAttempt = rhs.lastAttempt ?? .distantPast
                if lhsAttempt != rhsAttempt {
                    return lhsAttempt < rhsAttempt
                }
                return (lhs.lastRating ?? 0) < (rhs.lastRating ?? 0)
            }
    }

    static func scheduledProblems(
        in snapshot: SRLSnapshot,
        calendar: Calendar = .current
    ) -> [PracticeProblem] {
        snapshot.inProgress.compactMap { name, record in
            guard let attempt = record.history.last,
                  (1...5).contains(attempt.rating),
                  let lastDate = SRLDay.parse(attempt.date, calendar: calendar),
                  let dueDate = calendar.date(byAdding: .day, value: attempt.rating, to: lastDate)
            else {
                return nil
            }

            return PracticeProblem(
                name: name,
                url: record.url,
                lastRating: attempt.rating,
                lastAttempt: calendar.startOfDay(for: lastDate),
                dueDate: calendar.startOfDay(for: dueDate)
            )
        }
    }

    static func remainingRoute(
        in snapshot: SRLSnapshot,
        route: [RouteProblem]
    ) -> [RouteProblem] {
        let completedNames = Set(
            snapshot.inProgress.keys.map(normalize)
                + snapshot.mastered.keys.map(normalize)
        )
        let completedURLs = Set(
            (Array(snapshot.inProgress.values) + Array(snapshot.mastered.values))
                .compactMap(\.url)
                .map(normalizeURL)
        )

        return route.filter { problem in
            !completedNames.contains(normalize(problem.name))
                && !completedURLs.contains(normalizeURL(problem.url))
        }
    }

    static func activityCounts(
        in snapshot: SRLSnapshot,
        calendar: Calendar = .current
    ) -> [Date: Int] {
        var counts: [Date: Int] = [:]

        for record in Array(snapshot.inProgress.values) + Array(snapshot.mastered.values) {
            for attempt in record.history {
                guard let date = SRLDay.parse(attempt.date, calendar: calendar) else { continue }
                counts[calendar.startOfDay(for: date), default: 0] += 1
            }
        }

        for attempt in snapshot.audit.history where attempt.result == "pass" {
            guard let value = attempt.date,
                  let date = SRLDay.parse(value, calendar: calendar)
            else {
                continue
            }
            counts[calendar.startOfDay(for: date), default: 0] += 1
        }

        return counts
    }

    static func totalAttempts(in snapshot: SRLSnapshot) -> Int {
        attemptedQuestionSummaries(in: snapshot).reduce(0) { $0 + $1.attemptCount }
    }

    static func attemptedQuestionSummaries(
        in snapshot: SRLSnapshot
    ) -> [ActivityQuestionSummary] {
        var summariesByName: [String: ActivityQuestionSummary] = [:]
        var canonicalMetadata: [String: (name: String, url: String?)] = [:]

        func cleanURL(_ value: String?) -> String? {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }

        func seedMetadata(from records: [String: ProblemRecord]) {
            for (rawName, record) in sortedRecords(records) {
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let key = normalize(name)
                let url = cleanURL(record.url)

                if let existing = canonicalMetadata[key] {
                    canonicalMetadata[key] = (existing.name, existing.url ?? url)
                } else {
                    canonicalMetadata[key] = (name, url)
                }
            }
        }

        seedMetadata(from: snapshot.inProgress)
        seedMetadata(from: snapshot.mastered)

        func merge(name rawName: String, url: String?, attempts: Int, key explicitKey: String? = nil) {
            guard attempts > 0 else { return }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let key = explicitKey ?? normalize(name)
            let metadata = canonicalMetadata[key]
            let displayName = metadata?.name ?? name
            let usableURL = metadata?.url ?? cleanURL(url)

            if let existing = summariesByName[key] {
                summariesByName[key] = ActivityQuestionSummary(
                    id: existing.id,
                    name: existing.name,
                    url: existing.url ?? usableURL,
                    attemptCount: existing.attemptCount + attempts
                )
            } else {
                summariesByName[key] = ActivityQuestionSummary(
                    id: "attempted:\(key)",
                    name: displayName,
                    url: usableURL,
                    attemptCount: attempts
                )
            }
        }

        for (name, record) in sortedRecords(snapshot.inProgress) {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                merge(
                    name: "Unknown practice question",
                    url: record.url,
                    attempts: record.history.count,
                    key: "__unknown_practice_question__"
                )
            } else {
                merge(name: name, url: record.url, attempts: record.history.count)
            }
        }
        for (name, record) in sortedRecords(snapshot.mastered) {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                merge(
                    name: "Unknown practice question",
                    url: record.url,
                    attempts: record.history.count,
                    key: "__unknown_practice_question__"
                )
            } else {
                merge(name: name, url: record.url, attempts: record.history.count)
            }
        }

        for auditAttempt in snapshot.audit.history where auditAttempt.result == "pass" {
            let rawName = auditAttempt.problem?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let rawName, !rawName.isEmpty {
                merge(name: rawName, url: nil, attempts: 1)
            } else {
                merge(
                    name: "Unnamed audit",
                    url: nil,
                    attempts: 1,
                    key: "__unknown_audit_question__"
                )
            }
        }

        return summariesByName.values.sorted(by: summaryAttemptOrder)
    }

    static func questionSummaries(
        in records: [String: ProblemRecord]
    ) -> [ActivityQuestionSummary] {
        sortedRecords(records).map { name, record in
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL = record.url?.trimmingCharacters(in: .whitespacesAndNewlines)
            return ActivityQuestionSummary(
                id: "record:\(name)",
                name: trimmedName.isEmpty ? "Unknown practice question" : trimmedName,
                url: trimmedURL?.isEmpty == false ? trimmedURL : nil,
                attemptCount: record.history.count
            )
        }
    }

    static func scheduledByDay(
        in snapshot: SRLSnapshot,
        calendar: Calendar = .current
    ) -> [Date: [PracticeProblem]] {
        Dictionary(
            grouping: scheduledProblems(in: snapshot, calendar: calendar),
            by: { calendar.startOfDay(for: $0.dueDate ?? .distantPast) }
        ).mapValues { $0.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    }

    static func finishedByDay(
        in snapshot: SRLSnapshot,
        calendar: Calendar = .current
    ) -> [Date: [PracticeProblem]] {
        var finishedByDayAndName: [Date: [String: PracticeProblem]] = [:]
        let records = Array(snapshot.inProgress) + Array(snapshot.mastered)
        var canonicalRecords: [String: (name: String, url: String?)] = [:]

        for (name, record) in records {
            let normalizedName = normalize(name)
            guard !normalizedName.isEmpty else { continue }
            canonicalRecords[normalizedName] = (name, record.url)

            for attempt in record.history {
                guard (1...5).contains(attempt.rating),
                      let attemptDate = SRLDay.parse(attempt.date, calendar: calendar)
                else {
                    continue
                }

                let day = calendar.startOfDay(for: attemptDate)
                finishedByDayAndName[day, default: [:]][normalizedName] = PracticeProblem(
                    name: name,
                    url: record.url,
                    lastRating: attempt.rating,
                    lastAttempt: day,
                    dueDate: nil
                )
            }
        }

        for auditAttempt in snapshot.audit.history where auditAttempt.result == "pass" {
            guard let rawName = auditAttempt.problem?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawName.isEmpty,
                  let dateString = auditAttempt.date,
                  let attemptDate = SRLDay.parse(dateString, calendar: calendar)
            else {
                continue
            }

            let day = calendar.startOfDay(for: attemptDate)
            let normalizedName = normalize(rawName)
            let canonical = canonicalRecords[normalizedName]
            finishedByDayAndName[day, default: [:]][normalizedName] = PracticeProblem(
                name: canonical?.name ?? rawName,
                url: canonical?.url,
                lastRating: 5,
                lastAttempt: day,
                dueDate: nil
            )
        }

        return finishedByDayAndName.mapValues { problemsByName in
            problemsByName.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func normalizeURL(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            .lowercased()
    }

    private static func sortedRecords(
        _ records: [String: ProblemRecord]
    ) -> [(key: String, value: ProblemRecord)] {
        records.sorted { lhs, rhs in
            let comparison = lhs.key.localizedCaseInsensitiveCompare(rhs.key)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return lhs.key < rhs.key
        }
    }

    private static func summaryAttemptOrder(
        _ lhs: ActivityQuestionSummary,
        _ rhs: ActivityQuestionSummary
    ) -> Bool {
        if lhs.attemptCount != rhs.attemptCount {
            return lhs.attemptCount > rhs.attemptCount
        }
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        return lhs.name < rhs.name
    }
}
