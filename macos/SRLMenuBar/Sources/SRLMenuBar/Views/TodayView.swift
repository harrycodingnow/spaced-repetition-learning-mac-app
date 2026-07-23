import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var problemName = ""
    @State private var problemURL: String?
    @State private var selectedSuggestionName: String?
    @State private var rating = 3

    private let newQuestionCount = 3

    var body: some View {
        VStack(spacing: 8) {
            completionCard

            HStack(alignment: .top, spacing: 8) {
                revisionCard
                newQuestionsCard
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var completionCard: some View {
        SectionCard("Log a question", systemImage: "square.and.pencil") {
            HStack(spacing: 8) {
                TextField("Question name, e.g. Two Sum", text: $problemName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .onSubmit(saveAttempt)
                    .onChange(of: problemName) { newValue in
                        if newValue != selectedSuggestionName {
                            problemURL = nil
                            selectedSuggestionName = nil
                        }
                    }

                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = value
                        } label: {
                            Text("\(value)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 21, height: 22)
                                .foregroundColor(rating == value ? .white : ratingColor(value))
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            rating == value
                                                ? ratingColor(value)
                                                : ratingColor(value).opacity(0.12)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(ratingMeaning(value))
                        .accessibilityLabel("Rating \(value): \(ratingMeaning(value))")
                    }
                }
                .help("Review again in \(rating) day\(rating == 1 ? "" : "s"): \(ratingMeaning(rating))")

                Button {
                    saveAttempt()
                } label: {
                    if store.isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 40)
                    } else {
                        Text("Save")
                            .frame(width: 40)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.green)
                .disabled(store.isSaving || problemName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var revisionCard: some View {
        SectionCard("Revise", systemImage: "arrow.clockwise") {
            queueHeading(
                "Due today",
                count: store.dueToday.count,
                color: .orange
            )

            ScrollView {
                LazyVStack(spacing: 3) {
                    if store.dueToday.isEmpty {
                        Label("Nothing due", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(store.dueToday) { problem in
                            compactProblemButton(
                                name: problem.name,
                                subtitle: dueSubtitle(problem),
                                url: problem.url
                            )
                        }
                    }
                }
            }
            .scrollIndicators(.never)
            .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private var newQuestionsCard: some View {
        SectionCard("New question", systemImage: "sparkles") {
            queueHeading(
                "NeetCode 150",
                count: min(newQuestionCount, store.remainingRoute.count),
                color: .green
            )

            let nextQuestions = Array(store.remainingRoute.prefix(newQuestionCount))
            ScrollView {
                LazyVStack(spacing: 3) {
                    if nextQuestions.isEmpty {
                        Label("Route complete", systemImage: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(nextQuestions) { problem in
                            compactProblemButton(
                                name: problem.name,
                                subtitle: "#\(problem.routeIndex) · \(problem.category)",
                                url: problem.url
                            )
                        }
                    }
                }
            }
            .scrollIndicators(.never)
            .frame(height: 60)

            ProgressView(
                value: Double(store.routeCompletedCount),
                total: Double(max(store.route.count, 1))
            )
            .tint(.green)
            .controlSize(.mini)
        }
        .frame(maxWidth: .infinity)
    }

    private func queueHeading(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
            Spacer(minLength: 4)
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(Color.white.opacity(0.58))
        }
    }

    private func compactProblemButton(
        name: String,
        subtitle: String,
        url: String?
    ) -> some View {
        HStack(spacing: 5) {
            Button {
                selectedSuggestionName = name
                problemName = name
                problemURL = url
            } label: {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer(minLength: 3)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(Color.white.opacity(0.58))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Use \(name) in the entry form")

            ExternalLinkButton(urlString: url)
        }
        .frame(height: 20)
    }

    private func dueSubtitle(_ problem: PracticeProblem) -> String {
        guard let dueDate = problem.dueDate else { return "Due now" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: dueDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return days > 0 ? "\(days) day\(days == 1 ? "" : "s") overdue" : "Due today"
    }

    private func saveAttempt() {
        guard !store.isSaving else { return }
        let name = problemName
        let url = problemURL
        Task {
            if await store.recordAttempt(problem: name, rating: rating, url: url) {
                problemName = ""
                problemURL = nil
                selectedSuggestionName = nil
            }
        }
    }

    private func ratingMeaning(_ value: Int) -> String {
        switch value {
        case 1: return "Needed the solution"
        case 2: return "Significant struggle"
        case 3: return "Minor struggle"
        case 4: return "Solved smoothly"
        default: return "Confident and perfect"
        }
    }

    private func ratingColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .mint
        default: return .green
        }
    }
}
