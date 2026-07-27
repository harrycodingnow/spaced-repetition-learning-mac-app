import Foundation

enum QuestionInputParser {
    enum RatingSuffix: Equatable, Sendable {
        case none
        case pending
        case value(Int)
    }

    struct Result: Equatable, Sendable {
        let problemName: String
        let ratingSuffix: RatingSuffix
    }

    /// Parses the optional rating shorthand at the end of a question name.
    ///
    /// A suffix must be separated from the name by whitespace, so ordinary
    /// hyphenated names remain untouched. Rating range validation belongs to
    /// the repository.
    static func parse(_ input: String) -> Result {
        guard let separatorIndex = input.lastIndex(of: "-") else {
            return Result(problemName: input, ratingSuffix: .none)
        }

        let textBeforeSeparator = input[..<separatorIndex]
        guard textBeforeSeparator.last?.isWhitespace == true else {
            return Result(problemName: input, ratingSuffix: .none)
        }

        let baseName = String(textBeforeSeparator)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixStart = input.index(after: separatorIndex)
        let suffix = String(input[suffixStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if suffix.isEmpty {
            return Result(problemName: baseName, ratingSuffix: .pending)
        }

        guard suffix.allSatisfy(\.isNumber), let rating = Int(suffix) else {
            return Result(problemName: input, ratingSuffix: .none)
        }

        return Result(problemName: baseName, ratingSuffix: .value(rating))
    }
}
