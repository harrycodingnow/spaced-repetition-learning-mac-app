import SwiftUI

struct RouteView: View {
    @EnvironmentObject private var store: SRLDataStore

    private var completedNames: Set<String> {
        Set(
            store.snapshot.inProgress.keys.map(SRLScheduler.normalize)
                + store.snapshot.mastered.keys.map(SRLScheduler.normalize)
        )
    }

    private var completedURLs: Set<String> {
        Set(
            (Array(store.snapshot.inProgress.values) + Array(store.snapshot.mastered.values))
                .compactMap(\.url)
                .map(SRLScheduler.normalizeURL)
        )
    }

    private var categories: [String] {
        var seen = Set<String>()
        return store.route.compactMap { problem in
            seen.insert(problem.category).inserted ? problem.category : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionCard("NeetCode 150 route", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                    HStack {
                        Text("\(store.routeCompletedCount) of \(store.route.count) started or mastered")
                            .font(.subheadline)
                        Spacer()
                        Text("\(routePercent)%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundColor(.green)
                    }
                    ProgressView(
                        value: Double(store.routeCompletedCount),
                        total: Double(max(store.route.count, 1))
                    )
                    .tint(.green)
                }

                ForEach(categories, id: \.self) { category in
                    SectionCard(category, systemImage: "folder") {
                        ForEach(store.route.filter { $0.category == category }) { problem in
                            routeRow(problem)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func routeRow(_ problem: RouteProblem) -> some View {
        let completed = completedNames.contains(SRLScheduler.normalize(problem.name))
            || completedURLs.contains(SRLScheduler.normalizeURL(problem.url))

        return HStack(spacing: 9) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(completed ? .green : Color.white.opacity(0.48))
            Text("\(problem.routeIndex)")
                .font(.caption.monospacedDigit())
                .foregroundColor(Color.white.opacity(0.48))
                .frame(width: 24, alignment: .trailing)
            Text(problem.name)
                .font(.subheadline)
                .strikethrough(completed, color: Color.white.opacity(0.48))
                .foregroundColor(completed ? Color.white.opacity(0.48) : .white)
                .lineLimit(1)
            Spacer()
            ExternalLinkButton(urlString: problem.url)
        }
        .padding(.vertical, 1)
    }

    private var routePercent: Int {
        guard !store.route.isEmpty else { return 0 }
        return Int((Double(store.routeCompletedCount) / Double(store.route.count) * 100).rounded())
    }
}
