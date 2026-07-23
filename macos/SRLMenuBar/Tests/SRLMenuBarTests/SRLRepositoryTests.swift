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
