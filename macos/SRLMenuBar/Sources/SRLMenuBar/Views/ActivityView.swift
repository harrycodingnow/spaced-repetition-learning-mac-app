import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var selectedMetric: ActivityMetric?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(ActivityMetric.allCases) { metric in
                        metricButton(metric)
                    }
                }

                if let selectedMetric {
                    questionListCard(selectedMetric)
                        .transition(.opacity)
                } else {
                    heatmapCard
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .animation(.easeInOut(duration: 0.18), value: selectedMetric)
    }

    private func metricButton(_ metric: ActivityMetric) -> some View {
        Button {
            selectedMetric = selectedMetric == metric ? nil : metric
        } label: {
            MetricTile(
                value: metricValue(metric),
                label: metric.rawValue,
                color: metric.color,
                isSelected: selectedMetric == metric
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(metric.rawValue), \(metricValue(metric))")
        .accessibilityHint(
            selectedMetric == metric
                ? "Hide the question list"
                : "Show the question list"
        )
        .accessibilityAddTraits(selectedMetric == metric ? .isSelected : [])
    }

    private var heatmapCard: some View {
        SectionCard(
            "Past 52 weeks",
            systemImage: "calendar",
            showsBackground: false
        ) {
            ActivityHeatmap(counts: store.activityCounts, weeks: 52, cellSize: 11)
            Text("Each square counts completed attempts. Darker green means more practice.")
                .font(.caption)
                .foregroundColor(LiquidTheme.secondaryText)
        }
    }

    private func questionListCard(_ metric: ActivityMetric) -> some View {
        let questions = questions(for: metric)

        return SectionCard(
            "\(metric.rawValue) · \(questions.count)",
            systemImage: metric.systemImage,
            headerAccessory: {
                Button {
                    selectedMetric = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(LiquidTheme.secondaryText)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Return to activity grid")
                .accessibilityLabel("Close question list")
            }
        ) {
            Text(summaryText(for: metric, questions: questions))
                .font(.caption)
                .foregroundColor(LiquidTheme.secondaryText)

            if questions.isEmpty {
                Text("No questions yet.")
                    .font(.subheadline)
                    .foregroundColor(LiquidTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 118, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(questions) { question in
                            questionRow(question, metric: metric)
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(height: 118)
            }
        }
    }

    private func questionRow(
        _ question: ActivityQuestionSummary,
        metric: ActivityMetric
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: metric.rowSystemImage)
                .font(.caption2)
                .foregroundColor(metric.color)
                .frame(width: 14)

            Text(question.name)
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text("×\(question.attemptCount)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundColor(LiquidTheme.secondaryText)
                .help(
                    "\(question.attemptCount) attempt\(question.attemptCount == 1 ? "" : "s")"
                )

            ExternalLinkButton(urlString: question.url)
        }
        .frame(height: 22)
        .padding(.horizontal, 2)
    }

    private func questions(for metric: ActivityMetric) -> [ActivityQuestionSummary] {
        switch metric {
        case .totalAttempts: return store.attemptedQuestions
        case .mastered: return store.masteredQuestions
        case .inProgress: return store.inProgressQuestions
        }
    }

    private func metricValue(_ metric: ActivityMetric) -> String {
        switch metric {
        case .totalAttempts: return "\(store.totalAttempts)"
        case .mastered: return "\(store.snapshot.mastered.count)"
        case .inProgress: return "\(store.snapshot.inProgress.count)"
        }
    }

    private func summaryText(
        for metric: ActivityMetric,
        questions: [ActivityQuestionSummary]
    ) -> String {
        switch metric {
        case .totalAttempts:
            return "\(store.totalAttempts) attempts across \(questions.count) question\(questions.count == 1 ? "" : "s")"
        case .mastered:
            return "\(questions.count) mastered question\(questions.count == 1 ? "" : "s")"
        case .inProgress:
            return "\(questions.count) active question\(questions.count == 1 ? "" : "s")"
        }
    }
}

private enum ActivityMetric: String, CaseIterable, Identifiable {
    case totalAttempts = "Total attempts"
    case mastered = "Mastered"
    case inProgress = "In progress"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .totalAttempts: return .cyan
        case .mastered: return .green
        case .inProgress: return .orange
        }
    }

    var systemImage: String {
        switch self {
        case .totalAttempts: return "number"
        case .mastered: return "checkmark.seal"
        case .inProgress: return "clock.arrow.circlepath"
        }
    }

    var rowSystemImage: String {
        switch self {
        case .totalAttempts: return "circle.fill"
        case .mastered: return "checkmark.circle.fill"
        case .inProgress: return "clock.fill"
        }
    }
}
