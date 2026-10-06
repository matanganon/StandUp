import Foundation
import StandUpCore

/// Tiny Codable persistence over UserDefaults for settings and daily stats.
/// No database, no cloud. Corrupt data falls back to defaults.
struct PersistenceStore {
    private let defaults: UserDefaults
    private let settingsKey = "standup.settings.v1"
    private let statsKey = "standup.stats.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Settings

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else { return .standard }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            // Settings corruption → safe defaults.
            return .standard
        }
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    // MARK: Stats

    func loadStats() -> DailyStats {
        guard let data = defaults.data(forKey: statsKey) else {
            return DailyStats(day: Calendar.current.startOfDay(for: Date()))
        }
        do {
            return try JSONDecoder().decode(DailyStats.self, from: data)
        } catch {
            return DailyStats(day: Calendar.current.startOfDay(for: Date()))
        }
    }

    func saveStats(_ stats: DailyStats) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: statsKey)
        }
    }
}
