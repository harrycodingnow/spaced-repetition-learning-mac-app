import Testing
@testable import SRLMenuBar

struct QuestionInputParserTests {
    @Test("A compact trailing rating is parsed")
    func compactRating() {
        let result = QuestionInputParser.parse("Two Sum -5")

        #expect(result.problemName == "Two Sum")
        #expect(result.ratingSuffix == .value(5))
    }

    @Test("Whitespace after the separator is accepted")
    func spacedRating() {
        let result = QuestionInputParser.parse("Two Sum - 5")

        #expect(result.problemName == "Two Sum")
        #expect(result.ratingSuffix == .value(5))
    }

    @Test("Ordinary question names are unchanged")
    func ordinaryNames() {
        #expect(
            QuestionInputParser.parse("Two-Sum follow-up")
                == .init(problemName: "Two-Sum follow-up", ratingSuffix: .none)
        )
        #expect(
            QuestionInputParser.parse("Two Sum - Hard")
                == .init(problemName: "Two Sum - Hard", ratingSuffix: .none)
        )
    }

    @Test("A trailing separator is exposed as pending")
    func pendingRating() {
        let result = QuestionInputParser.parse("Two Sum -")

        #expect(result.problemName == "Two Sum")
        #expect(result.ratingSuffix == .pending)
    }

    @Test("An empty base is returned safely")
    func emptyBase() {
        #expect(
            QuestionInputParser.parse(" -5")
                == .init(problemName: "", ratingSuffix: .value(5))
        )
        #expect(
            QuestionInputParser.parse(" -")
                == .init(problemName: "", ratingSuffix: .pending)
        )
    }

    @Test("Numeric suffixes are parsed without rating range validation")
    func outOfRangeRating() {
        #expect(
            QuestionInputParser.parse("Two Sum -9")
                == .init(problemName: "Two Sum", ratingSuffix: .value(9))
        )
        #expect(
            QuestionInputParser.parse("Two Sum -0")
                == .init(problemName: "Two Sum", ratingSuffix: .value(0))
        )
    }
}
