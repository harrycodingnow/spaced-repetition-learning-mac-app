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
        let problemAttempts = (Array(snapshot.inProgress.values) + Array(snapshot.mastered.values))
            .reduce(0) { $0 + $1.history.count }
        let passedAudits = snapshot.audit.history.filter { $0.result == "pass" }.count
        return problemAttempts + passedAudits
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

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizeURL(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            .lowercased()
    }
}
