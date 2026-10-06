import Foundation

/// Simple local daily statistics. Counts reset when the local calendar day changes.
public struct DailyStats: Equatable, Codable, Sendable {
    public var completedBreaks: Int
    public var snoozes: Int
    public var skippedBreaks: Int
    public var activeWorkSeconds: TimeInterval
    /// The day (start-of-day) these counts belong to.
    public var day: Date

    public init(
        completedBreaks: Int = 0,
        snoozes: Int = 0,
        skippedBreaks: Int = 0,
        activeWorkSeconds: TimeInterval = 0,
        day: Date = Date(timeIntervalSinceReferenceDate: 0)
    ) {
        self.completedBreaks = completedBreaks
        self.snoozes = snoozes
        self.skippedBreaks = skippedBreaks
        self.activeWorkSeconds = activeWorkSeconds
        self.day = day
    }

    /// Returns stats rolled over to `now`'s calendar day, zeroing counts if the day changed.
    public func rolledOver(to now: Date, calendar: Calendar = .current) -> DailyStats {
        let today = calendar.startOfDay(for: now)
        if calendar.isDate(day, inSameDayAs: today) {
            return self
        }
        return DailyStats(day: today)
    }

    public var activeWorkMinutes: Int {
        Int(activeWorkSeconds / 60)
    }
}
