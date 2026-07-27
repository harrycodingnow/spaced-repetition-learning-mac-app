import Foundation
import Testing
@testable import SRLMenuBar

struct StudyRouteTests {
    @Test("Every bundled study route is complete and internally consistent")
    func bundledRoutes() {
        for studyRoute in StudyRoute.allCases {
            let problems = NeetCodeRoute.bundled(studyRoute)

            #expect(problems.count == studyRoute.expectedQuestionCount)
            #expect(problems.map(\.routeIndex) == Array(1...studyRoute.expectedQuestionCount))
            #expect(Set(problems.map { SRLScheduler.normalize($0.name) }).count == problems.count)
            #expect(Set(problems.map { SRLScheduler.normalizeURL($0.url) }).count == problems.count)
            #expect(problems.allSatisfy { !$0.category.isEmpty && !$0.name.isEmpty })
            #expect(problems.allSatisfy {
                $0.url.hasPrefix("https://leetcode.com/problems/")
                    && $0.url.hasSuffix("/description/")
            })
        }
    }

    @Test("Shared questions stay canonical across route sizes")
    func routeNesting() {
        let blind75 = NeetCodeRoute.bundled(.blind75)
        let neetCode150 = NeetCodeRoute.bundled(.neetCode150)
        let neetCode250 = NeetCodeRoute.bundled(.neetCode250)
        let neetCode150ByURL = Dictionary(
            uniqueKeysWithValues: neetCode150.map { (SRLScheduler.normalizeURL($0.url), $0) }
        )
        let neetCode250ByURL = Dictionary(
            uniqueKeysWithValues: neetCode250.map { (SRLScheduler.normalizeURL($0.url), $0) }
        )

        for problem in blind75 {
            let shared = neetCode150ByURL[SRLScheduler.normalizeURL(problem.url)]
            #expect(shared?.name == problem.name)
            #expect(shared?.category == problem.category)
        }

        for problem in neetCode150 {
            let shared = neetCode250ByURL[SRLScheduler.normalizeURL(problem.url)]
            #expect(shared?.name == problem.name)
            #expect(shared?.category == problem.category)
        }
    }

    @MainActor
    @Test("Route choice defaults to NeetCode 150 and persists")
    func selectionPersistence() throws {
        let suiteName = "StudyRouteTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        preferences.removePersistentDomain(forName: suiteName)
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let initialStore = SRLDataStore(preferences: preferences)
        #expect(initialStore.selectedStudyRoute == .neetCode150)
        #expect(initialStore.route.count == 150)

        initialStore.selectedStudyRoute = .blind75
        let restoredStore = SRLDataStore(preferences: preferences)
        #expect(restoredStore.selectedStudyRoute == .blind75)
        #expect(restoredStore.route.count == 75)
    }
}
