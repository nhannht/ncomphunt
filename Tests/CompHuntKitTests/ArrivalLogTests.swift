import Foundation
import Testing
@testable import CompHuntKit

@Suite struct ArrivalLogTests {
    /// A fixed calendar so the tests do not move with the machine's timezone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Fold a whole run of presence samples the way the app does, returning the
    /// final state plus every moment that was reported as an arrival.
    private func replay(
        _ samples: [Date], threshold: TimeInterval = ArrivalLog.absenceThreshold,
        limit: Int = ArrivalLog.sampleLimit
    ) -> (arrivals: [Date], fired: [Date]) {
        var last: Date?
        var arrivals: [Date] = []
        var fired: [Date] = []
        for sample in samples {
            let update = ArrivalLog.observe(sample, lastPresence: last,
                                            arrivals: arrivals,
                                            threshold: threshold, limit: limit)
            if update.isArrival { fired.append(sample) }
            last = update.lastPresence
            arrivals = update.arrivals
        }
        return (arrivals, fired)
    }

    // MARK: what counts as coming back

    /// A fresh install must not fire a notification seconds after launch. The
    /// first sample only establishes where the clock is.
    @Test func theFirstSampleEverSeedsWithoutFiring() {
        let update = ArrivalLog.observe(date(2026, 8, 5, 9, 0),
                                        lastPresence: nil, arrivals: [])
        #expect(update.isArrival == false)
        #expect(update.arrivals.isEmpty)
        #expect(update.lastPresence == date(2026, 8, 5, 9, 0))
    }

    @Test func steppingOutForLunchIsNotComingBack() {
        let (arrivals, fired) = replay([
            date(2026, 8, 5, 9, 0),
            date(2026, 8, 5, 12, 0),
            date(2026, 8, 5, 14, 0),  // two hours away
        ])
        #expect(fired.isEmpty)
        #expect(arrivals.isEmpty)
    }

    @Test func aNightAwayIsComingBack() {
        let (_, fired) = replay([
            date(2026, 8, 4, 23, 0),
            date(2026, 8, 5, 9, 30),
        ])
        #expect(fired == [date(2026, 8, 5, 9, 30)])
    }

    /// The exact shape of 2026-08-05, the night that produced this design. The
    /// user was at the machine until 01:45, the Mac slept, and they came back at
    /// 12:42. The samples in between do not exist BECAUSE the caller only
    /// samples while the screen is awake - a sleeping Mac dark-wakes every few
    /// minutes all night and the app runs through every one of them, so feeding
    /// those in would have fired a digest at 02:41.
    @Test func theRealOvernightTimelineYieldsExactlyOneArrival() {
        let (arrivals, fired) = replay([
            date(2026, 8, 5, 0, 31),
            date(2026, 8, 5, 1, 0),
            date(2026, 8, 5, 1, 44),
            date(2026, 8, 5, 1, 45),
            // asleep 01:45 -> 12:42, no samples taken
            date(2026, 8, 5, 12, 42),
            date(2026, 8, 5, 12, 43),
            date(2026, 8, 5, 13, 0),
        ])
        #expect(fired == [date(2026, 8, 5, 12, 42)])
        #expect(arrivals == [date(2026, 8, 5, 12, 42)])
    }

    /// A timezone change or an NTP correction moves the clock backwards. That is
    /// arithmetic, not a person walking back to their desk.
    @Test func aClockMovingBackwardsDoesNotManufactureAnArrival() {
        let update = ArrivalLog.observe(
            date(2026, 8, 5, 9, 0),
            lastPresence: date(2026, 8, 5, 15, 0), arrivals: [])
        #expect(update.isArrival == false)
        // The clock is still followed, so the next real gap measures from here.
        #expect(update.lastPresence == date(2026, 8, 5, 9, 0))
    }

    @Test func theLogKeepsOnlyTheMostRecentArrivals() {
        let samples = (1...5).map { date(2026, 8, $0, 9, 0) }
        let (arrivals, fired) = replay(samples, limit: 3)
        #expect(fired.count == 4)  // every day after the first is a return
        #expect(arrivals == [date(2026, 8, 3, 9), date(2026, 8, 4, 9),
                             date(2026, 8, 5, 9)])
    }

    // MARK: learning the morning

    @Test func nothingIsLearnedBeforeThereIsAHabit() {
        let notEnough = (1...ArrivalLog.minimumSamplesToLearn - 1).map {
            date(2026, 8, $0, 9, 0)
        }
        #expect(ArrivalLog.learnedMorning(from: notEnough, calendar: calendar) == nil)
        #expect(ArrivalLog.learnedMorning(from: [], calendar: calendar) == nil)
    }

    /// Median, not mean. One night up at 03:00 must not drag the estimate two
    /// hours earlier for the rest of the month.
    @Test func oneOddNightDoesNotMoveTheLearnedMorning() {
        let arrivals = [
            date(2026, 8, 1, 9, 0),
            date(2026, 8, 2, 9, 10),
            date(2026, 8, 3, 3, 0),   // the outlier
            date(2026, 8, 4, 9, 20),
            date(2026, 8, 5, 9, 30),
        ]
        let learned = ArrivalLog.learnedMorning(from: arrivals, calendar: calendar)
        #expect(learned?.hour == 9)
        #expect(learned?.minute == 10)
    }

    @Test func theLearnedMorningIsAnHourAndMinute() {
        let arrivals = (1...5).map { date(2026, 8, $0, 13, 45) }
        let learned = ArrivalLog.learnedMorning(from: arrivals, calendar: calendar)
        #expect(learned?.hour == 13)
        #expect(learned?.minute == 45)
    }

    // MARK: scheduling from it (iOS only)

    @Test func theNextOccurrenceIsStrictlyAfterTheGivenMoment() throws {
        let morning = DateComponents(hour: 9, minute: 15)
        let afterIt = try #require(ArrivalLog.nextOccurrence(
            of: morning, after: date(2026, 8, 5, 12, 0), calendar: calendar))
        #expect(afterIt == date(2026, 8, 6, 9, 15))

        let beforeIt = try #require(ArrivalLog.nextOccurrence(
            of: morning, after: date(2026, 8, 5, 6, 0), calendar: calendar))
        #expect(beforeIt == date(2026, 8, 5, 9, 15))
    }

    /// Asked exactly on the minute, it must move to tomorrow rather than
    /// returning a date that has already arrived.
    @Test func theNextOccurrenceSkipsTheMomentItIsAskedOn() throws {
        let next = try #require(ArrivalLog.nextOccurrence(
            of: DateComponents(hour: 9, minute: 15),
            after: date(2026, 8, 5, 9, 15), calendar: calendar))
        #expect(next == date(2026, 8, 6, 9, 15))
    }
}
