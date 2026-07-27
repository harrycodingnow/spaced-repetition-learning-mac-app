import Foundation

enum QuestionAutocomplete {
    static func bestMatch(for query: String, among candidates: [String]) -> String? {
        let normalizedQuery = normalize(query)
        guard normalizedQuery.count >= 2 else { return nil }

        let normalizedCandidates = candidates.map { candidate in
            (name: candidate, normalized: normalize(candidate))
        }

        guard !normalizedCandidates.contains(where: { $0.normalized == normalizedQuery })
        else {
            return nil
        }

        return normalizedCandidates.first(where: {
            $0.normalized.hasPrefix(normalizedQuery)
        })?.name
    }

    static func uniqueSaveMatch(for query: String, among candidates: [String]) -> String? {
        let normalizedQuery = normalize(query)
        guard normalizedQuery.count >= 8,
              normalizedQuery.split(separator: " ").count >= 2
        else {
            return nil
        }

        var seen = Set<String>()
        let matches = candidates.compactMap { candidate -> String? in
            let normalizedCandidate = normalize(candidate)
            guard normalizedCandidate.hasPrefix(normalizedQuery),
                  seen.insert(normalizedCandidate).inserted
            else {
                return nil
            }
            return candidate
        }

        return matches.count == 1 ? matches[0] : nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}
