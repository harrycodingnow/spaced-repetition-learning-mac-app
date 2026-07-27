import Foundation
import Testing
@testable import SRLMenuBar

struct SRLRepositoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Two consecutive fives move a question to mastered")
    func masteryTransition() async throws {
        let fixture = try TemporarySRLDirectory()
        defer { fixture.remove() }
        let repository = SRLRepository(dataDirectory: fixture.url)
        let day = try #require(SRLDay.parse("2026-07-23", calendar: calendar))

        _ = try await repository.recordAttempt(
            problem: "Two Sum",
            rating: 5,
            on: day,
            calendar: calendar
        )
        let result = try await repository.recordAttempt(
            problem: "two sum",
            rating: 5,
            on: day,
            calendar: calendar
        )
        let snapshot = try await repository.loadSnapshot()

        #expect(result.mastered)
        #expect(snapshot.inProgress.isEmpty)
        #expect(snapshot.mastered["Two Sum"]?.history.map(\.rating) == [5, 5])
    }

    @Test("Recording a queued question carries its URL and removes it from Next Up")
    func queueCompatibility() async throws {
        let fixture = try TemporarySRLDirectory()
        defer { fixture.remove() }
        let nextUp = [
            "Two Sum": NextUpRecord(
                added: "2026-07-20",
                url: "https://leetcode.com/problems/two-sum/description/"
            ),
        ]
        try fixture.write(nextUp, filename: "next_up.json")
        let repository = SRLRepository(dataDirectory: fixture.url)
        let day = try #require(SRLDay.parse("2026-07-23", calendar: calendar))

        _ = try await repository.recordAttempt(
            problem: "two sum",
            rating: 3,
            on: day,
            calendar: calendar
        )
        let snapshot = try await repository.loadSnapshot()

        #expect(snapshot.nextUp.isEmpty)
        #expect(snapshot.inProgress["two sum"]?.url == "https://leetcode.com/problems/two-sum/description/")
        #expect(snapshot.inProgress["two sum"]?.history.first?.date == "2026-07-23")
    }

    @Test("A unique typo appends to the canonical due question")
    func dueQuestionTypo() async throws {
        let fixture = try TemporarySRLDirectory()
        defer { fixture.remove() }
        let existing = [
            "Valid Palindrome": ProblemRecord(
                history: [Attempt(rating: 1, date: "2026-07-22")],
                url: "https://leetcode.com/problems/valid-palindrome/description/"
            ),
        ]
        try fixture.write(existing, filename: "problems_in_progress.json")
        let repository = SRLRepository(dataDirectory: fixture.url)
        let day = try #require(SRLDay.parse("2026-07-23", calendar: calendar))

        let result = try await repository.recordAttempt(
            problem: "valid palindrom",
            rating: 4,
            on: day,
            calendar: calendar
        )
        let snapshot = try await repository.loadSnapshot()

        #expect(result.problemName == "Valid Palindrome")
        #expect(snapshot.inProgress["Valid Palindrome"]?.history.map(\.rating) == [1, 4])
        #expect(snapshot.inProgress["valid palindrom"] == nil)
    }

    @Test("Rewriting Next Up records adds stable NeetCode route indexes")
    func queueRouteOrder() async throws {
        let fixture = try TemporarySRLDirectory()
        defer { fixture.remove() }
        let nextUp = [
            "Contains Duplicate": NextUpRecord(),
            "Valid Anagram": NextUpRecord(),
            "Two Sum": NextUpRecord(),
        ]
        try fixture.write(nextUp, filename: "next_up.json")
        let repository = SRLRepository(dataDirectory: fixture.url)
        let day = try #require(SRLDay.parse("2026-07-23", calendar: calendar))

        _ = try await repository.recordAttempt(
            problem: "Two Sum",
            rating: 3,
            on: day,
            calendar: calendar
        )
        let snapshot = try await repository.loadSnapshot()

        #expect(snapshot.nextUp["Contains Duplicate"]?.order == 1)
        #expect(snapshot.nextUp["Valid Anagram"]?.order == 2)
    }

    @Test("A malformed legacy file produces a useful error")
    func corruptFileError() async throws {
        let fixture = try TemporarySRLDirectory()
        defer { fixture.remove() }
        try Data("not json".utf8).write(
            to: fixture.url.appendingPathComponent("problems_in_progress.json")
        )
        let repository = SRLRepository(dataDirectory: fixture.url)

        do {
            _ = try await repository.loadSnapshot()
            Issue.record("Expected malformed JSON to throw")
        } catch {
            #expect(error.localizedDescription.contains("problems_in_progress.json"))
        }
    }

    @MainActor
    @Test("A successful store save immediately advances the visible route")
    func storeSaveAdvancesRoute() async throws {
        let fixture = try TemporarySRLDirectory()
        defer { fixture.remove() }
        let suiteName = "StoreRouteAdvanceTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        preferences.removePersistentDomain(forName: suiteName)
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let route = (1...4).map { index in
            RouteProblem(
                routeIndex: index,
                category: "Arrays",
                name: "Question \(index)",
                url: "https://example.com/question-\(index)/"
            )
        }
        let store = SRLDataStore(
            repository: SRLRepository(dataDirectory: fixture.url),
            routes: [.neetCode150: route],
            preferences: preferences,
            calendar: calendar
        )

        await store.refresh()
        #expect(Array(store.remainingRoute.prefix(3)).map(\.routeIndex) == [1, 2, 3])

        let saved = await store.recordAttempt(
            problem: route[0].name,
            rating: 3,
            url: route[0].url
        )

        #expect(saved)
        #expect(Array(store.remainingRoute.prefix(3)).map(\.routeIndex) == [2, 3, 4])
    }
}

private struct TemporarySRLDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("srl-menubar-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write<T: Encodable>(_ value: T, filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try encoder.encode(value).write(to: url.appendingPathComponent(filename))
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
