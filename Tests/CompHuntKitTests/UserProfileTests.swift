import Foundation
import SwiftData
import Testing
@testable import CompHuntKit

private func comp(
    _ title: String,
    tags: [CompetitionCategory],
    status: CompetitionStatus? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: "test", title: title, url: "https://example.com/\(title)")
    let competition = Competition(dto: dto, tags: tags, region: .global)
    competition.status = status
    return competition
}

/// The mark-vote seeding: every mark is a vote for its categories, the
/// pipeline is the confidence scale, and no marks means no suggestion.
@Suite struct ProfileSeedingTests {
    @Test func advancingThePipelineIsAStrongerVoteThanStarring() {
        let suggested = UserProfile.suggestedInterests(from: [
            comp("starred ctf", tags: [.ctf], status: .interested),
            comp("joined round", tags: [.cp], status: .joined),
        ])
        #expect(suggested[.cp] == 1.0)
        #expect(suggested[.ctf] == 1.0 / 3.0)
    }

    @Test func droppedIsAVoteAgainst() {
        let suggested = UserProfile.suggestedInterests(from: [
            comp("kept", tags: [.ai], status: .joined),
            comp("dropped essay 1", tags: [.writing], status: .dropped),
            comp("dropped essay 2", tags: [.writing], status: .dropped),
        ])
        #expect(suggested[.ai] == 1.0)
        // Net-negative clamps to 0: a recorded "not this", stronger than
        // the neutral a never-voted category keeps.
        #expect(suggested[.writing] == 0)
    }

    @Test func unmarkedRowsAndUntouchedCategoriesStayOut() {
        let suggested = UserProfile.suggestedInterests(from: [
            comp("just browsed", tags: [.design]),
            comp("marked", tags: [.ctf], status: .interested),
        ])
        // Browsing votes for nothing, and design was never voted on, so the
        // caller keeps whatever weight it already had.
        #expect(suggested[.design] == nil)
        #expect(suggested.keys.count == 1)
    }

    @Test func aMarkVotesForEveryTagTheRowCarries() {
        let suggested = UserProfile.suggestedInterests(from: [
            comp("ai hackathon", tags: [.hackathon, .ai], status: .applied)
        ])
        #expect(suggested[.hackathon] == 1.0)
        #expect(suggested[.ai] == 1.0)
    }

    /// The cold-start rule: an empty or unmarked store suggests nothing
    /// rather than an all-zero profile.
    @Test func noMarksMeansNoSuggestion() {
        #expect(UserProfile.suggestedInterests(from: []).isEmpty)
        #expect(UserProfile.suggestedInterests(
            from: [comp("unmarked", tags: [.cp])]).isEmpty)
    }
}

@Suite struct UserProfileModelTests {
    @Test func interestsRoundTripThroughTheRawString() {
        let profile = UserProfile()
        profile.interests = [.ctf: 0.8, .cp: 0.25]
        // Category declaration order, so equal weights always serialize
        // identically and the fingerprint is deterministic.
        #expect(profile.interestsRaw == "cp:0.25,ctf:0.8")
        #expect(profile.interests == [.cp: 0.25, .ctf: 0.8])
    }

    @Test func garbageInTheRawStringReadsAsUnset() {
        let profile = UserProfile()
        profile.interestsRaw = "cp:0.5,nonsense:9,ctf:not-a-number,:,"
        #expect(profile.interests == [.cp: 0.5])
    }

    @Test func fingerprintMovesWithEveryScoringField() {
        let profile = UserProfile()
        var seen: Set<String> = [profile.fingerprint]
        profile.interests = [.cp: 1]
        #expect(seen.insert(profile.fingerprint).inserted)
        profile.cfRating = 1450
        #expect(seen.insert(profile.fingerprint).inserted)
        profile.weeklyHours = 20
        #expect(seen.insert(profile.fingerprint).inserted)
        profile.prizeFloorUSD = 100
        #expect(seen.insert(profile.fingerprint).inserted)
        profile.preferredRegion = .vietnam
        #expect(seen.insert(profile.fingerprint).inserted)
    }

    @Test func snapshotCarriesTheFieldsTheScorerReads() {
        let profile = UserProfile()
        profile.interests = [.ai: 0.9]
        profile.cfRating = 1450
        profile.prizeFloorUSD = 50
        profile.preferredRegion = .vietnam
        let zone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let snapshot = profile.snapshot(timezone: zone)
        #expect(snapshot.interests == [.ai: 0.9])
        #expect(snapshot.cfRating == 1450)
        #expect(snapshot.prizeFloorUSD == 50)
        #expect(snapshot.preferredRegion == .vietnam)
        #expect(snapshot.timezone == zone)
    }

    @MainActor
    @Test func fetchOrCreateIsSingular() throws {
        let container = try ModelContainer(
            for: Competition.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let first = try UserProfile.fetchOrCreate(in: context)
        first.weeklyHours = 25
        try context.save()
        let second = try UserProfile.fetchOrCreate(in: context)
        #expect(second.weeklyHours == 25)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).count == 1)
    }

    /// The COMP-16 acceptance criterion: the profile lives OUTSIDE the
    /// rebuildable cache, so the prune that deletes stale leads cannot
    /// touch it.
    @MainActor
    @Test func profileSurvivesAFullPrune() throws {
        let container = try ModelContainer(
            for: Competition.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let profile = try UserProfile.fetchOrCreate(in: context)
        profile.interests = [.ctf: 1]
        let stale = comp("stale dateless lead", tags: [.other])
        stale.lastSeen = Date(timeIntervalSince1970: 0)
        context.insert(stale)
        try context.save()

        let pruned = try CompetitionStore.prune(context)

        #expect(pruned == 1)
        #expect(try context.fetch(FetchDescriptor<Competition>()).isEmpty)
        let kept = try #require(
            try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(kept.interests == [.ctf: 1])
    }
}
