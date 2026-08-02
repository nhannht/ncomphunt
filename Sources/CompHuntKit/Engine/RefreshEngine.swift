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
        SourceID.allCases.map { $0.makeSource() }
    }

    /// Registry order, filtered to what the user enabled. `includeSearch`
    /// gates the metered search-engine sources separately (the app includes
    /// them at most once per day).
    public static func sources(
        enabled: Set<SourceID>, includeSearch: Bool
    ) -> [any CompetitionSource] {
        SourceID.allCases
            .filter { enabled.contains($0) && (includeSearch || !$0.isSearch) }
            .map { $0.makeSource() }
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
        // Rows this fetch did not return are unreachable by the loop above, so
        // the classifier is run over the leftovers here rather than only over
        // what a feed happens to be listing today.
        _ = try? CompetitionStore.reclassifyUnplaced(context)
        _ = try? CompetitionStore.prune(context, now: now)
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
        // Dedupe within the batch: earliest occurrence (richest source) wins,
        // but absorbs any fields it was missing from later duplicates.
        var indexByKey: [String: Int] = [:]
        var unique: [CompetitionDTO] = []
        for dto in dtos {
            if let index = indexByKey[dto.key] {
                unique[index].fillMissing(from: dto)
            } else {
                indexByKey[dto.key] = unique.count
                unique.append(dto)
            }
        }

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

    /// Re-runs the classifier over rows already in the store that never landed
    /// anywhere.
    ///
    /// A row is classified once, at the moment a source hands it over. A feed
    /// only lists what is current, so a row that scrolled off keeps whatever
    /// answer the classifier gave the day it was last served. Measured on a
    /// live store: ybox listed 44 competitions while the store held 117, so 73
    /// rows carried answers from a build with four fewer categories in it and
    /// no refresh could ever reach them.
    ///
    /// Scoped to `.other` deliberately. A row that already has a category may
    /// have got it from a source that DECLARED it - CTFtime, Codeforces and
    /// MLContests all set `dto.category` directly - and the store does not
    /// record which answers were declared and which were guessed. Re-deriving
    /// those from stored text would downgrade them: `NextGen Innovation2026` is
    /// `.ai` because MLContests says so, and nothing in its title says it.
    /// `.other` is the one value with nothing below it, so this pass can only
    /// improve a row, never spoil one.
    @MainActor
    @discardableResult
    public static func reclassifyUnplaced(_ context: ModelContext) throws -> Int {
        let unplaced = CompetitionCategory.other.rawValue
        let descriptor = FetchDescriptor<Competition>(
            predicate: #Predicate { $0.categoryRaw == unplaced })
        var moved = 0
        for row in try context.fetch(descriptor) {
            // `category: nil` on purpose: passing the stored `.other` would be
            // read as a source declaring it and short-circuit the classifier.
            let dto = CompetitionDTO(
                source: row.source, title: row.title, organizer: row.organizer,
                url: row.url, category: nil, location: row.location,
                prize: row.prize, details: row.details)
            let category = Classifier.category(for: dto)
            guard category != .other else { continue }
            row.categoryRaw = category.rawValue
            moved += 1
        }
        if moved > 0 {
            try context.save()
        }
        return moved
    }

    /// Deletes stale dateless leads. Rows with no dates (mostly search hits)
    /// can never expire through `isCurrent`, so they age out once unseen for
    /// `maxAge`. Rows carrying user state are never pruned: a YouTrack issue
    /// id, or a status the person set. The store is a rebuildable cache of the
    /// feeds, but what someone marked is not rebuildable from anywhere.
    @MainActor
    @discardableResult
    public static func prune(
        _ context: ModelContext,
        olderThan maxAge: TimeInterval = 14 * 24 * 3600,
        now: Date = .now
    ) throws -> Int {
        let cutoff = now.addingTimeInterval(-maxAge)
        let descriptor = FetchDescriptor<Competition>(
            predicate: #Predicate { $0.lastSeen < cutoff })
        let stale = try context.fetch(descriptor).filter { row in
            row.startDate == nil && row.endDate == nil
                && row.registrationDeadline == nil
                && row.trackedIssueID == nil
                && row.statusRaw == nil
        }
        for row in stale {
            context.delete(row)
        }
        if !stale.isEmpty {
            try context.save()
        }
        return stale.count
    }
}
