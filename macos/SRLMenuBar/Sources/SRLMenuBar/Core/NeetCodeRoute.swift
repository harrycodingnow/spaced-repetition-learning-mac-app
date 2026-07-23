import Foundation

enum NeetCodeRoute {
    static func bundled() -> [RouteProblem] {
        if let appURL = Bundle.main.url(
            forResource: "neetcode_150_route",
            withExtension: "csv"
        ), let csv = try? String(contentsOf: appURL, encoding: .utf8) {
            return parse(csv: csv)
        }

        guard let packageURL = Bundle.module.url(
            forResource: "neetcode_150_route",
            withExtension: "csv"
        ), let csv = try? String(contentsOf: packageURL, encoding: .utf8) else { return [] }

        return parse(csv: csv)
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
