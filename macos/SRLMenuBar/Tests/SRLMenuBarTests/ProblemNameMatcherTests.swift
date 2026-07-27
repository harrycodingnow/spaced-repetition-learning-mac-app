import Testing
@testable import SRLMenuBar

struct ProblemNameMatcherTests {
    @Test("A unique missing-character typo resolves to its due question")
    func missingCharacter() {
        let match = ProblemNameMatcher.uniqueNearMatch(
            for: "valid palindrom",
            among: ["Valid Palindrome", "Two Sum"]
        )

        #expect(match == "Valid Palindrome")
    }

    @Test("Case and repeated whitespace resolve exactly")
    func exactNormalizedName() {
        let match = ProblemNameMatcher.uniqueNearMatch(
            for: "  VALID   PALINDROME ",
            among: ["Valid Palindrome"]
        )

        #expect(match == "Valid Palindrome")
    }

    @Test("An adjacent transposition is treated as one typo")
    func transposition() {
        let match = ProblemNameMatcher.uniqueNearMatch(
            for: "Valid Plaindrome",
            among: ["Valid Palindrome"]
        )

        #expect(match == "Valid Palindrome")
    }

    @Test("Ambiguous one-edit matches are not resolved")
    func ambiguousMatch() {
        let match = ProblemNameMatcher.uniqueNearMatch(
            for: "valid palindrom",
            among: ["Valid Palindroma", "Valid Palindromi"]
        )

        #expect(match == nil)
    }

    @Test("Names more than one edit apart remain new")
    func distantName() {
        let match = ProblemNameMatcher.uniqueNearMatch(
            for: "Valid Palindrmx",
            among: ["Valid Palindrome"]
        )

        #expect(match == nil)
    }

    @Test("Short names never use fuzzy matching")
    func shortName() {
        let match = ProblemNameMatcher.uniqueNearMatch(
            for: "3Su",
            among: ["3Sum"]
        )

        #expect(match == nil)
    }
}
