import Foundation
import Testing
@testable import SRLMenuBar

struct SRLSchedulerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("A question is due on last attempt date plus its rating")
    func dueDateMatchesLegacyCLI() throws {
        let snapshot = SRLSnapshot(
            inProgress: [
                "Due": ProblemRecord(history: [Attempt(rating: 2, date: "2026-07-21")]),
                "Tomorrow": ProblemRecord(history: [Attempt(rating: 3, date: "2026-07-21")]),
            ],
            mastered: [:],
            nextUp: [:],
            audit: AuditStore()
        )
        let today = try #require(SRLDay.parse("2026-07-23", calendar: calendar))

        let due = SRLScheduler.dueProblems(in: snapshot, on: today, calendar: calendar)

        #expect(due.map(\.name) == ["Due"])
        #expect(due.first?.dueDate == SRLDay.parse("2026-07-23", calendar: calendar))
    }

    @Test("Due questions sort by oldest attempt, then lower rating")
    func dueSortOrder() throws {
        let snapshot = SRLSnapshot(
            inProgress: [
                "Rating three": ProblemRecord(history: [Attempt(rating: 3, date: "2026-07-18")]),
                "Oldest": ProblemRecord(history: [Attempt(rating: 5, date: "2026-07-17")]),
                "Rating one": ProblemRecord(history: [Attempt(rating: 1, date: "2026-07-18")]),
            ],
            mastered: [:],
            nextUp: [:],
            audit: AuditStore()
        )
        let today = try #require(SRLDay.parse("2026-07-23", calendar: calendar))

        let names = SRLScheduler.dueProblems(in: snapshot, on: today, calendar: calendar).map(\.name)

        #expect(names == ["Oldest", "Rating one", "Rating three"])
    }

    @Test("Activity includes passed audits but not failed audit records")
    func activityParity() throws {
        let snapshot = SRLSnapshot(
            inProgress: [
                "Two Sum": ProblemRecord(history: [
                    Attempt(rating: 2, date: "2026-07-20"),
                    Attempt(rating: 4, date: "2026-07-20"),
                ]),
            ],
            mastered: [:],
            nextUp: [:],
            audit: AuditStore(history: [
                AuditAttempt(date: "2026-07-20", problem: "A", result: "pass"),
                AuditAttempt(date: "2026-07-20", problem: "B", result: "fail"),
            ])
        )
        let day = try #require(SRLDay.parse("2026-07-20", calendar: calendar))

        let counts = SRLScheduler.activityCounts(in: snapshot, calendar: calendar)

        #expect(counts[day] == 3)
        #expect(SRLScheduler.totalAttempts(in: snapshot) == 3)
    }

    @Test("The bundled NeetCode route is complete, ordered, and categorized")
    func routeResource() {
        let route = NeetCodeRoute.bundled()
        let expectedCounts = [9, 5, 6, 6, 7, 11, 15, 7, 10, 3, 13, 6, 12, 11, 8, 6, 8, 7]
        var categoryOrder: [String] = []
        var categoryCounts: [String: Int] = [:]

        for problem in route {
            if categoryCounts[problem.category] == nil {
                categoryOrder.append(problem.category)
            }
            categoryCounts[problem.category, default: 0] += 1
        }

        #expect(route.count == 150)
        #expect(Set(route.map(\.name)).count == 150)
        #expect(route.first?.name == "Contains Duplicate")
        #expect(categoryOrder.map { categoryCounts[$0] ?? 0 } == expectedCounts)
    }

    @Test("Started or mastered questions are removed from the route")
    func remainingRouteFiltersNamesAndURLs() {
        let route = [
            RouteProblem(routeIndex: 1, category: "Arrays", name: "Two Sum", url: "https://example.com/two-sum/"),
            RouteProblem(routeIndex: 2, category: "Arrays", name: "Valid Anagram", url: "https://example.com/anagram/"),
        ]
        let snapshot = SRLSnapshot(
            inProgress: ["two sum": ProblemRecord(history: [])],
            mastered: ["Renamed": ProblemRecord(history: [], url: "https://example.com/anagram")],
            nextUp: [:],
            audit: AuditStore()
        )

        #expect(SRLScheduler.remainingRoute(in: snapshot, route: route).isEmpty)
    }
}
