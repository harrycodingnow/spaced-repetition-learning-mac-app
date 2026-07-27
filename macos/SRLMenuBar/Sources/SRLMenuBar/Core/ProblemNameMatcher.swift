import Foundation

enum ProblemNameMatcher {
    static func uniqueNearMatch(for input: String, among candidates: [String]) -> String? {
        let normalizedInput = normalize(input)
        guard !normalizedInput.isEmpty else { return nil }

        var namesByNormalized: [String: String] = [:]
        for candidate in candidates.sorted(by: localizedNameOrder) {
            let normalizedCandidate = normalize(candidate)
            guard !normalizedCandidate.isEmpty else { continue }
            namesByNormalized[normalizedCandidate] = namesByNormalized[normalizedCandidate]
                ?? candidate
        }

        if let exactMatch = namesByNormalized[normalizedInput] {
            return exactMatch
        }

        guard normalizedInput.count >= 5 else { return nil }
        let nearMatches: [String] = namesByNormalized.compactMap { entry -> String? in
            let (normalizedCandidate, candidate) = entry
            guard normalizedCandidate.count >= 5,
                  isOneEditApart(normalizedInput, normalizedCandidate)
            else {
                return nil
            }
            return candidate
        }

        return nearMatches.count == 1 ? nearMatches[0] : nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func localizedNameOrder(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private static func isOneEditApart(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs)
        let right = Array(rhs)
        let lengthDifference = left.count - right.count
        guard abs(lengthDifference) <= 1 else { return false }

        if lengthDifference == 0 {
            let mismatches = left.indices.filter { left[$0] != right[$0] }
            if mismatches.count == 1 { return true }
            guard mismatches.count == 2,
                  mismatches[1] == mismatches[0] + 1
            else {
                return false
            }
            return left[mismatches[0]] == right[mismatches[1]]
                && left[mismatches[1]] == right[mismatches[0]]
        }

        let shorter = lengthDifference < 0 ? left : right
        let longer = lengthDifference < 0 ? right : left
        var shortIndex = 0
        var longIndex = 0
        var skippedCharacter = false

        while shortIndex < shorter.count, longIndex < longer.count {
            if shorter[shortIndex] == longer[longIndex] {
                shortIndex += 1
                longIndex += 1
            } else if skippedCharacter {
                return false
            } else {
                skippedCharacter = true
                longIndex += 1
            }
        }

        return true
    }
}
