import Combine
import Foundation

@MainActor
final class SRLDataStore: ObservableObject {
    @Published private(set) var snapshot: SRLSnapshot = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var notice: String?
    @Published var errorMessage: String?

    let route: [RouteProblem]
    let dataDirectory: URL

    private let repository: SRLRepository
    private let calendar: Calendar

    init(
        repository: SRLRepository = SRLRepository(),
        route: [RouteProblem] = NeetCodeRoute.bundled(),
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.route = route
        self.calendar = calendar
        self.dataDirectory = repository.dataDirectory
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

    var totalAttempts: Int {
        SRLScheduler.totalAttempts(in: snapshot)
    }

    var routeCompletedCount: Int {
        route.count - remainingRoute.count
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await repository.loadSnapshot()
            errorMessage = nil
        } catch {
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
            errorMessage = error.localizedDescription
            return false
        }
    }
}
