import Foundation
import Darwin

enum SRLRepositoryError: LocalizedError, Sendable {
    case emptyProblemName
    case invalidRating(Int)
    case invalidData(file: String, reason: String)
    case lockFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyProblemName:
            return "Enter the question you finished."
        case let .invalidRating(rating):
            return "Rating \(rating) is invalid. Choose a rating from 1 to 5."
        case let .invalidData(file, reason):
            return "Could not read \(file): \(reason)"
        case let .lockFailed(reason):
            return "Could not lock the shared SRL data: \(reason)"
        }
    }
}

actor SRLRepository {
    let dataDirectory: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let routeOrderByName: [String: Int]
    private let routeOrderByURL: [String: Int]

    init(
        dataDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".srl", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.dataDirectory = dataDirectory
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        self.encoder = encoder
        self.decoder = JSONDecoder()

        let route = NeetCodeRoute.bundled()
        self.routeOrderByName = Dictionary(
            uniqueKeysWithValues: route.map { (SRLScheduler.normalize($0.name), $0.routeIndex) }
        )
        self.routeOrderByURL = Dictionary(
            uniqueKeysWithValues: route.map { (SRLScheduler.normalizeURL($0.url), $0.routeIndex) }
        )
    }

    func loadSnapshot() throws -> SRLSnapshot {
        try ensureDataDirectory()
        return try withDataLock(exclusive: false) {
            try loadSnapshotWithoutPreparingDirectory()
        }
    }

    func recordAttempt(
        problem rawName: String,
        rating: Int,
        url suppliedURL: String? = nil,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> RecordResult {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw SRLRepositoryError.emptyProblemName }
        guard (1...5).contains(rating) else { throw SRLRepositoryError.invalidRating(rating) }

        try ensureDataDirectory()
        return try withDataLock(exclusive: true) {
            var snapshot = try loadSnapshotWithoutPreparingDirectory()
            let exactName = canonicalKey(in: snapshot.inProgress, matching: trimmedName)
            let dueNames = SRLScheduler.dueProblems(
                in: snapshot,
                on: date,
                calendar: calendar
            ).map(\.name)
            let canonicalName = exactName
                ?? ProblemNameMatcher.uniqueNearMatch(for: trimmedName, among: dueNames)
                ?? trimmedName
            var record = snapshot.inProgress[canonicalName] ?? ProblemRecord()

            let queueKey = canonicalKey(in: snapshot.nextUp, matching: canonicalName)
            let queueURL = queueKey.flatMap { snapshot.nextUp[$0]?.url }
            let cleanSuppliedURL = suppliedURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleanSuppliedURL, !cleanSuppliedURL.isEmpty {
                record.url = cleanSuppliedURL
            } else if record.url?.isEmpty != false, let queueURL, !queueURL.isEmpty {
                record.url = queueURL
            }

            record.history.append(
                Attempt(rating: rating, date: SRLDay.string(date, calendar: calendar))
            )

            let becameMastered = record.history.count >= 2
                && record.history.suffix(2).allSatisfy { $0.rating == 5 }

            if becameMastered {
                let masteredName = canonicalKey(in: snapshot.mastered, matching: canonicalName) ?? canonicalName
                if var existing = snapshot.mastered[masteredName] {
                    existing.history.append(contentsOf: record.history)
                    if existing.url?.isEmpty != false {
                        existing.url = record.url
                    }
                    snapshot.mastered[masteredName] = existing
                } else {
                    snapshot.mastered[masteredName] = record
                }
                snapshot.inProgress.removeValue(forKey: canonicalName)
            } else {
                snapshot.inProgress[canonicalName] = record
            }

            var nextUpChanged = false
            if let queueKey {
                snapshot.nextUp.removeValue(forKey: queueKey)
                nextUpChanged = true
            } else if let recordURL = record.url {
                let normalizedURL = SRLScheduler.normalizeURL(recordURL)
                if let matchingURLKey = snapshot.nextUp.first(where: {
                    guard let url = $0.value.url else { return false }
                    return SRLScheduler.normalizeURL(url) == normalizedURL
                })?.key {
                    snapshot.nextUp.removeValue(forKey: matchingURLKey)
                    nextUpChanged = true
                }
            }

            if becameMastered {
                // Write the destination before deleting from progress. A crash can
                // temporarily duplicate a record, but it cannot lose the history.
                try write(snapshot.mastered, to: "problems_mastered.json")
            }
            try write(snapshot.inProgress, to: "problems_in_progress.json")
            if nextUpChanged {
                snapshot.nextUp = queueWithStableRouteOrder(snapshot.nextUp)
                try write(snapshot.nextUp, to: "next_up.json")
            }

            return RecordResult(
                problemName: canonicalName,
                mastered: becameMastered,
                message: becameMastered
                    ? "\(canonicalName) is mastered. Nice work!"
                    : "Saved rating \(rating) for \(canonicalName)."
            )
        }
    }

    private func loadSnapshotWithoutPreparingDirectory() throws -> SRLSnapshot {
        SRLSnapshot(
            inProgress: try read(
                [String: ProblemRecord].self,
                from: "problems_in_progress.json",
                default: [:]
            ),
            mastered: try read(
                [String: ProblemRecord].self,
                from: "problems_mastered.json",
                default: [:]
            ),
            nextUp: try read(
                [String: NextUpRecord].self,
                from: "next_up.json",
                default: [:]
            ),
            audit: try read(
                AuditStore.self,
                from: "audit.json",
                default: AuditStore()
            )
        )
    }

    private func read<T: Decodable>(
        _ type: T.Type,
        from filename: String,
        default defaultValue: T
    ) throws -> T {
        let url = dataDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return defaultValue }

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { return defaultValue }
            return try decoder.decode(type, from: data)
        } catch {
            throw SRLRepositoryError.invalidData(file: filename, reason: error.localizedDescription)
        }
    }

    private func write<T: Encodable>(_ value: T, to filename: String) throws {
        let url = dataDirectory.appendingPathComponent(filename)
        var data = try encoder.encode(value)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
    }

    private func ensureDataDirectory() throws {
        try fileManager.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true
        )
    }

    private func withDataLock<T>(exclusive: Bool, operation: () throws -> T) throws -> T {
        let lockURL = dataDirectory.appendingPathComponent(".lock")
        let descriptor = Darwin.open(
            lockURL.path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else {
            throw SRLRepositoryError.lockFailed(String(cString: strerror(errno)))
        }
        defer { Darwin.close(descriptor) }

        let lockOperation = exclusive ? LOCK_EX : LOCK_SH
        guard flock(descriptor, lockOperation) == 0 else {
            throw SRLRepositoryError.lockFailed(String(cString: strerror(errno)))
        }
        defer { flock(descriptor, LOCK_UN) }

        return try operation()
    }

    private func queueWithStableRouteOrder(
        _ queue: [String: NextUpRecord]
    ) -> [String: NextUpRecord] {
        var orderedQueue = queue
        for key in orderedQueue.keys {
            guard var record = orderedQueue[key], record.order == nil else { continue }
            record.order = routeOrderByName[SRLScheduler.normalize(key)]
                ?? record.url.flatMap { routeOrderByURL[SRLScheduler.normalizeURL($0)] }
            orderedQueue[key] = record
        }
        return orderedQueue
    }

    private func canonicalKey<Value>(
        in dictionary: [String: Value],
        matching name: String
    ) -> String? {
        let normalized = SRLScheduler.normalize(name)
        return dictionary.keys.first { SRLScheduler.normalize($0) == normalized }
    }
}
