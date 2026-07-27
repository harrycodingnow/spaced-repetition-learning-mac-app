import Testing
@testable import SRLMenuBar

struct QuestionAutocompleteTests {
    @Test("A name prefix returns the first prioritized candidate")
    func prefixMatch() {
        let match = QuestionAutocomplete.bestMatch(
            for: "valid p",
            among: ["Valid Palindrome", "Validate Binary Search Tree"]
        )

        #expect(match == "Valid Palindrome")
    }

    @Test("A full-name prefix outranks an earlier word prefix")
    func prefixPriority() {
        let match = QuestionAutocomplete.bestMatch(
            for: "med",
            among: ["Find Median from Data Stream", "Median of Two Sorted Arrays"]
        )

        #expect(match == "Median of Two Sorted Arrays")
    }

    @Test("A non-leading word does not trigger an unexpected completion")
    func noWordPrefix() {
        let match = QuestionAutocomplete.bestMatch(
            for: "pal",
            among: ["Two Sum", "Valid Palindrome"]
        )

        #expect(match == nil)
    }

    @Test("Exact names and one-character queries do not suggest")
    func noUnhelpfulSuggestion() {
        #expect(
            QuestionAutocomplete.bestMatch(
                for: "two sum",
                among: ["Two Sum", "Two Sum II - Input Array Is Sorted"]
            ) == nil
        )
        #expect(QuestionAutocomplete.bestMatch(for: "t", among: ["Two Sum"]) == nil)
    }

    @Test("Matching ignores case and repeated whitespace")
    func normalizedMatch() {
        let match = QuestionAutocomplete.bestMatch(
            for: "  VALID   aN  ",
            among: ["Valid Anagram"]
        )

        #expect(match == "Valid Anagram")
    }

    @Test("A unique prefix can be resolved safely when saving")
    func uniquePrefix() {
        #expect(
            QuestionAutocomplete.uniqueSaveMatch(
                for: "two sum ii input",
                among: ["Two Sum II Input Array Is Sorted", "3Sum"]
            ) == "Two Sum II Input Array Is Sorted"
        )
        #expect(
            QuestionAutocomplete.uniqueSaveMatch(
                for: "valid",
                among: ["Valid Anagram", "Valid Palindrome"]
            ) == nil
        )
        #expect(
            QuestionAutocomplete.uniqueSaveMatch(
                for: "rotate",
                among: ["Rotate Image"]
            ) == nil
        )
    }
}
