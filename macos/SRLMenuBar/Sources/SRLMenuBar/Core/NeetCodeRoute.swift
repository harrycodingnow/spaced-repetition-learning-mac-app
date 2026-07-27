import Foundation

enum StudyRoute: String, CaseIterable, Identifiable, Sendable {
    case blind75 = "blind_75"
    case neetCode150 = "neetcode_150"
    case neetCode250 = "neetcode_250"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blind75: return "Blind 75"
        case .neetCode150: return "NeetCode 150"
        case .neetCode250: return "NeetCode 250"
        }
    }

    var resourceName: String {
        "\(rawValue)_route"
    }

    var expectedQuestionCount: Int {
        switch self {
        case .blind75: return 75
        case .neetCode150: return 150
        case .neetCode250: return 250
        }
    }
}

enum NeetCodeRoute {
    static func bundled(_ studyRoute: StudyRoute = .neetCode150) -> [RouteProblem] {
        if let appURL = Bundle.main.url(
            forResource: studyRoute.resourceName,
            withExtension: "csv"
        ), let csv = try? String(contentsOf: appURL, encoding: .utf8) {
            return parse(csv: csv)
        }

        guard let packageURL = Bundle.module.url(
            forResource: studyRoute.resourceName,
            withExtension: "csv"
        ), let csv = try? String(contentsOf: packageURL, encoding: .utf8) else { return [] }

        return parse(csv: csv)
    }

    static func bundledRoutes() -> [StudyRoute: [RouteProblem]] {
        Dictionary(
            uniqueKeysWithValues: StudyRoute.allCases.map { studyRoute in
                (studyRoute, bundled(studyRoute))
            }
        )
    }

    static func parse(csv: String) -> [RouteProblem] {
        csv.split(whereSeparator: \.isNewline)
            .dropFirst()
            .enumerated()
            .compactMap { offset, line in
                let columns = line.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
                guard columns.count == 3 else { return nil }

                let category = columns[0].trimmingCharacters(in: .whitespaces)
                let name = columns[1].trimmingCharacters(in: .whitespaces)
                let url = columns[2].trimmingCharacters(in: .whitespaces)
                guard !category.isEmpty, !name.isEmpty, !url.isEmpty else { return nil }

                return RouteProblem(
                    routeIndex: offset + 1,
                    category: category,
                    name: name,
                    url: url
                )
            }
    }
}
