import Foundation
import SwiftData

public struct RefreshReport: Sendable {
    public struct SourceResult: Sendable {
        public enum Outcome: Sendable, Equatable {
            case ok
            case skipped(String)
            case failed(String)
        }

        public let source: String
        public let fetched: Int
        public let outcome: Outcome
    }

    public let results: [SourceResult]
    /// Titles of competitions first seen in this run, for notifications.
    public let newTitles: [String]

    public var newCount: Int { newTitles.count }
}

/// Fans out over sources concurrently and upserts into SwiftData.
/// A source that throws is reported and skipped; it never kills the run.
public struct RefreshEngine: Sendable {
    private let sources: [any CompetitionSource]

    public init(sources: [any CompetitionSource]) {
        self.sources = sources
    }

    /// Every production source, richest first: on duplicate URLs within one
    /// batch the earliest source's fields win.
    public static func standardSources() -> [any CompetitionSource] {
        [
            CTFtimeSource(),
            DevpostSource(),
            ClistSource(),
            YboxSource(),
            ContestWatchersSource(),
        ]
    }

    /// Network + parse stage only; no persistence.
    public func fetchAll() async -> (dtos: [CompetitionDTO], results: [RefreshReport.SourceResult]) {
        var bySource: [String: Result<[CompetitionDTO], Error>] = [:]
        await withTaskGroup(of: (String, Result<[CompetitionDTO], Error>).self) { group in
            for source in sources {
                group.addTask {
                    do {
                        return (source.name, .success(try await source.fetch()))
                    } catch {
                        return (source.name, .failure(error))
                    }
                }
            }
            for await (name, result) in group {
                bySource[name] = result
            }
        }

        var dtos: [CompetitionDTO] = []
        var results: [RefreshReport.SourceResult] = []
        // Report in declaration order, not completion order.
        for source in sources {
            switch bySource[source.name] {
            case .success(let batch):
                dtos += batch
                results.append(.init(source: source.name, fetched: batch.count, outcome: .ok))
            case .failure(let error as SourceSkipped):
                results.append(.init(source: source.name, fetched: 0, outcome: .skipped(error.reason)))
            case .failure(let error):
                results.append(.init(source: source.name, fetched: 0, outcome: .failed(String(describing: error))))
            case nil:
                break
            }
        }
        return (dtos, results)
    }

    /// Full refresh: fetch, classify, dedupe, upsert. Persistence runs on the
    /// caller's actor via the passed context (the app passes its main context).
    @MainActor
    public func refresh(into context: ModelContext, now: Date = .now) async -> RefreshReport {
        let (dtos, results) = await fetchAll()
        let newTitles = (try? CompetitionStore.upsert(dtos, into: context, now: now)) ?? []
        return RefreshReport(results: results, newTitles: newTitles)
    }
}

public enum CompetitionStore {
    /// Upserts a batch, preserving `firstSeen` and tracking state on existing
    /// rows. Returns titles of newly inserted competitions.
    @MainActor
    public static func upsert(
        _ dtos: [CompetitionDTO],
        into context: ModelContext,
        now: Date = .now
    ) throws -> [String] {
        // Dedupe within the batch first: earliest occurrence (richest source) wins.
        var seenKeys = Set<String>()
        let unique = dtos.filter { seenKeys.insert($0.key).inserted }

        var newTitles: [String] = []
        for dto in unique {
            let category = Classifier.category(for: dto)
            let region = Classifier.region(for: dto)
            let key = dto.key
            let descriptor = FetchDescriptor<Competition>(
                predicate: #Predicate { $0.key == key })
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: dto, category: category, region: region, now: now)
            } else {
                context.insert(Competition(dto: dto, category: category, region: region, now: now))
                newTitles.append(dto.title)
            }
        }
        try context.save()
        return newTitles
    }
}
