import Combine
import Foundation

@MainActor
final class SRLDataStore: ObservableObject {
    @Published private(set) var snapshot: SRLSnapshot = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var notice: String?
    @Published var errorMessage: String?
    @Published var selectedStudyRoute: StudyRoute {
        didSet {
            preferences.set(selectedStudyRoute.rawValue, forKey: Self.selectedStudyRouteKey)
        }
    }

    let dataDirectory: URL

    private let repository: SRLRepository
    private let calendar: Calendar
    private let routes: [StudyRoute: [RouteProblem]]
    private let preferences: UserDefaults
    private var snapshotGeneration = 0
    private static let selectedStudyRouteKey = "selectedStudyRoute.v1"

    init(
        repository: SRLRepository = SRLRepository(),
        routes: [StudyRoute: [RouteProblem]] = NeetCodeRoute.bundledRoutes(),
        preferences: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.routes = routes
        self.preferences = preferences
        self.selectedStudyRoute = preferences.string(forKey: Self.selectedStudyRouteKey)
            .flatMap(StudyRoute.init(rawValue:))
            ?? .neetCode150
        self.calendar = calendar
        self.dataDirectory = repository.dataDirectory
    }

    var route: [RouteProblem] {
        routes[selectedStudyRoute] ?? []
    }

    var dueToday: [PracticeProblem] {
        SRLScheduler.dueProblems(in: snapshot, calendar: calendar)
    }

    var remainingRoute: [RouteProblem] {
        SRLScheduler.remainingRoute(in: snapshot, route: route)
    }

    var activityCounts: [Date: Int] {
        SRLScheduler.activityCounts(in: snapshot, calendar: calendar)
    }

    var scheduledByDay: [Date: [PracticeProblem]] {
        SRLScheduler.scheduledByDay(in: snapshot, calendar: calendar)
    }

    var finishedByDay: [Date: [PracticeProblem]] {
        SRLScheduler.finishedByDay(in: snapshot, calendar: calendar)
    }

    var totalAttempts: Int {
        SRLScheduler.totalAttempts(in: snapshot)
    }

    var attemptedQuestions: [ActivityQuestionSummary] {
        SRLScheduler.attemptedQuestionSummaries(in: snapshot)
    }

    var masteredQuestions: [ActivityQuestionSummary] {
        SRLScheduler.questionSummaries(in: snapshot.mastered)
    }

    var inProgressQuestions: [ActivityQuestionSummary] {
        SRLScheduler.questionSummaries(in: snapshot.inProgress)
    }

    var routeCompletedCount: Int {
        route.count - remainingRoute.count
    }

    func refresh() async {
        let requestedGeneration = snapshotGeneration
        isLoading = true
        defer { isLoading = false }

        do {
            let refreshedSnapshot = try await repository.loadSnapshot()
            guard requestedGeneration == snapshotGeneration else { return }
            snapshot = refreshedSnapshot
            errorMessage = nil
        } catch {
            guard requestedGeneration == snapshotGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func recordAttempt(
        problem: String,
        rating: Int,
        url: String? = nil
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        snapshotGeneration &+= 1
        notice = nil
        errorMessage = nil
        defer { isSaving = false }

        do {
            let result = try await repository.recordAttempt(
                problem: problem,
                rating: rating,
                url: url
            )
            snapshot = try await repository.loadSnapshot()
            notice = result.message
            errorMessage = nil
            return true
        } catch {
            notice = nil
            errorMessage = error.localizedDescription
            return false
        }
    }
}
