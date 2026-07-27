import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var problemName = ""
    @State private var problemURL: String?
    @State private var selectedSuggestionName: String?
    @State private var rating = 3

    private let newQuestionCount = 3

    private struct AutocompleteCandidate {
        let name: String
        let url: String?
    }

    var body: some View {
        VStack(spacing: 8) {
            completionCard
                .zIndex(1)

            HStack(alignment: .top, spacing: 8) {
                revisionCard
                newQuestionsCard
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var completionCard: some View {
        SectionCard(
            "Log a question",
            systemImage: "square.and.pencil",
            usesLiquidGlass: true,
            headerAccessory: { completionHeaderAccessory }
        ) {
            HStack(spacing: 8) {
                questionField

                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            selectRating(value)
                        } label: {
                            Text("\(value)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 22, height: 24)
                                .foregroundColor(
                                    effectiveRating == value
                                        ? selectedRatingForeground(value)
                                        : ratingColor(value)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(
                                            effectiveRating == value
                                                ? ratingColor(value).opacity(0.88)
                                                : Color.white.opacity(0.045)
                                        )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(
                                            effectiveRating == value
                                                ? Color.white.opacity(0.20)
                                                : ratingColor(value).opacity(0.18),
                                            lineWidth: 0.6
                                        )
                                }
                                .shadow(
                                    color: effectiveRating == value
                                        ? ratingColor(value).opacity(0.24)
                                        : .clear,
                                    radius: 5,
                                    y: 2
                                )
                        }
                        .buttonStyle(.plain)
                        .help(ratingMeaning(value))
                        .accessibilityLabel("Rating \(value): \(ratingMeaning(value))")
                        .accessibilityAddTraits(
                            effectiveRating == value ? .isSelected : []
                        )
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                )
                .animation(.easeInOut(duration: 0.16), value: effectiveRating)
                .help(
                    "Review again in \(effectiveRating) day\(effectiveRating == 1 ? "" : "s"): "
                        + ratingMeaning(effectiveRating)
                )

                Button {
                    saveAttempt()
                } label: {
                    if store.isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 40)
                    } else {
                        Text("Save")
                            .frame(width: 42)
                    }
                }
                .liquidButtonStyle(prominent: true, tint: LiquidTheme.accent)
                .controlSize(.small)
                .disabled(store.isSaving || parsedQuestionInput.problemName.isEmpty)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.notice)
    }

    private var questionField: some View {
        TabCompletingTextField(
            text: $problemName,
            placeholder: "Question, e.g. Two Sum -5",
            completion: autocompleteCompletedInput,
            onAcceptCompletion: acceptCurrentAutocomplete,
            onSubmit: saveAttempt
        )
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
        }
        .help("Append -1 through -5 to set the rating. Press Tab to accept a suggestion.")
        .accessibilityLabel("Question")
        .accessibilityHint(autocompleteAccessibilityHint)
        .onChange(of: problemName, perform: questionTextDidChange)
    }

    @ViewBuilder
    private var completionHeaderAccessory: some View {
        if autocompleteSuggestion != nil {
            autocompleteAccessory
        } else if let notice = store.notice {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.medium))
                .foregroundColor(LiquidTheme.accent)
                .lineLimit(1)
                .frame(maxWidth: 270, alignment: .trailing)
                .help(notice)
                .accessibilityLabel(notice)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var autocompleteAccessory: some View {
        if let suggestion = autocompleteSuggestion {
            Button {
                acceptAutocomplete(suggestion)
            } label: {
                HStack(spacing: 5) {
                    Text(suggestion.name)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(LiquidTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("Tab")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.white.opacity(0.09))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                        }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Complete as \(suggestion.name)")
            .accessibilityLabel("Suggestion: \(suggestion.name)")
            .accessibilityHint("Press Tab or click to complete")
            .transition(.opacity)
        }
    }

    private var revisionCard: some View {
        SectionCard(
            "Revise today",
            systemImage: "arrow.clockwise",
            showsBackground: false
        ) {
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

            ProgressView(value: 0, total: 1)
                .controlSize(.mini)
                .hidden()
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var newQuestionsCard: some View {
        SectionCard(
            "New question",
            systemImage: "sparkles",
            showsBackground: false,
            headerAccessory: { StudyRoutePicker() }
        ) {
            let nextQuestions = Array(store.remainingRoute.prefix(newQuestionCount))
            ScrollView {
                VStack(spacing: 3) {
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
                .id(
                    "\(store.selectedStudyRoute.rawValue):"
                        + nextQuestions.map { "\($0.routeIndex):\($0.name)" }.joined(separator: "|")
                )
            }
            .scrollIndicators(.never)
            .frame(height: 60)

            ProgressView(
                value: Double(store.routeCompletedCount),
                total: Double(max(store.route.count, 1))
            )
            .tint(LiquidTheme.accent)
            .controlSize(.mini)
        }
        .frame(maxWidth: .infinity)
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
                        .foregroundColor(LiquidTheme.secondaryText)
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

    private var autocompleteCandidates: [AutocompleteCandidate] {
        var candidates: [AutocompleteCandidate] = []
        var indexByName: [String: Int] = [:]

        func addCandidate(name: String, url: String?) {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = SRLScheduler.normalize(trimmedName)
            guard !normalizedName.isEmpty else { return }

            let trimmedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
            let usableURL = trimmedURL?.isEmpty == false ? trimmedURL : nil
            if let index = indexByName[normalizedName] {
                if candidates[index].url == nil, usableURL != nil {
                    candidates[index] = AutocompleteCandidate(
                        name: candidates[index].name,
                        url: usableURL
                    )
                }
                return
            }

            indexByName[normalizedName] = candidates.count
            candidates.append(AutocompleteCandidate(name: trimmedName, url: usableURL))
        }

        for problem in store.dueToday {
            addCandidate(name: problem.name, url: problem.url)
        }

        let queuedQuestions = store.snapshot.nextUp.sorted { lhs, rhs in
            let lhsOrder = lhs.value.order ?? Int.max
            let rhsOrder = rhs.value.order ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

            let lhsAdded = lhs.value.added ?? ""
            let rhsAdded = rhs.value.added ?? ""
            if lhsAdded != rhsAdded { return lhsAdded < rhsAdded }

            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }
        for (name, record) in queuedQuestions {
            addCandidate(name: name, url: record.url)
        }

        for problem in store.remainingRoute {
            addCandidate(name: problem.name, url: problem.url)
        }

        for (name, record) in store.snapshot.inProgress.sorted(by: {
            $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }) {
            addCandidate(name: name, url: record.url)
        }

        return candidates
    }

    private var autocompleteSuggestion: AutocompleteCandidate? {
        let candidates = autocompleteCandidates
        guard let matchedName = QuestionAutocomplete.bestMatch(
            for: parsedQuestionInput.problemName,
            among: candidates.map(\.name)
        ) else {
            return nil
        }

        return candidates.first { $0.name == matchedName }
    }

    private var autocompleteCompletedInput: String? {
        guard let suggestion = autocompleteSuggestion else { return nil }
        return completedInput(for: suggestion)
    }

    private var autocompleteAccessibilityHint: String {
        guard let suggestion = autocompleteSuggestion else {
            return "Append -1 through -5 to set the rating."
        }
        return "Suggestion: \(suggestion.name). Press Tab to complete."
    }

    private func completedInput(for suggestion: AutocompleteCandidate) -> String {
        switch parsedQuestionInput.ratingSuffix {
        case .none:
            return suggestion.name
        case .pending:
            return "\(suggestion.name) -"
        case let .value(value):
            return "\(suggestion.name) -\(value)"
        }
    }

    private func acceptCurrentAutocomplete() {
        guard let suggestion = autocompleteSuggestion else { return }
        selectedSuggestionName = suggestion.name
        problemURL = suggestion.url
    }

    private func acceptAutocomplete(_ suggestion: AutocompleteCandidate) {
        selectedSuggestionName = suggestion.name
        problemURL = suggestion.url
        problemName = completedInput(for: suggestion)
    }

    private func questionTextDidChange(_ newValue: String) {
        let parsed = QuestionInputParser.parse(newValue)
        if case let .value(value) = parsed.ratingSuffix,
           (1...5).contains(value) {
            rating = value
        }

        if let selectedSuggestionName,
           SRLScheduler.normalize(parsed.problemName)
            != SRLScheduler.normalize(selectedSuggestionName) {
            problemURL = nil
            self.selectedSuggestionName = nil
        }
    }

    private func saveAttempt() {
        guard !store.isSaving else { return }
        let parsed = parsedQuestionInput
        let candidates = autocompleteCandidates
        let exactCandidate = candidates.first {
            SRLScheduler.normalize($0.name) == SRLScheduler.normalize(parsed.problemName)
        }
        let inferredCandidate: AutocompleteCandidate?
        if let inferredName = QuestionAutocomplete.uniqueSaveMatch(
            for: parsed.problemName,
            among: candidates.map(\.name)
        ) {
            inferredCandidate = candidates.first { $0.name == inferredName }
        } else {
            inferredCandidate = nil
        }
        let matchedCandidate = exactCandidate ?? inferredCandidate
        let name = matchedCandidate?.name ?? parsed.problemName
        let attemptRating: Int
        if case let .value(value) = parsed.ratingSuffix {
            attemptRating = value
        } else {
            attemptRating = rating
        }
        let url = problemURL ?? matchedCandidate?.url
        Task {
            if await store.recordAttempt(problem: name, rating: attemptRating, url: url) {
                problemName = ""
                problemURL = nil
                selectedSuggestionName = nil
            }
        }
    }

    private func selectRating(_ value: Int) {
        rating = value
        switch parsedQuestionInput.ratingSuffix {
        case .pending, .value:
            problemName = parsedQuestionInput.problemName
        case .none:
            break
        }
    }

    private var parsedQuestionInput: QuestionInputParser.Result {
        let parsed = QuestionInputParser.parse(problemName)
        return .init(
            problemName: parsed.problemName.trimmingCharacters(in: .whitespacesAndNewlines),
            ratingSuffix: parsed.ratingSuffix
        )
    }

    private var effectiveRating: Int {
        if case let .value(value) = parsedQuestionInput.ratingSuffix,
           (1...5).contains(value) {
            return value
        }
        return rating
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

    private func selectedRatingForeground(_ value: Int) -> Color {
        value <= 2 ? .white : Color.black.opacity(0.82)
    }
}
