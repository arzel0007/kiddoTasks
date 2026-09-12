import Foundation

/// Birthday helpers for parent + kids surfaces.
enum BirthdayReminder {
    struct Upcoming: Identifiable, Hashable {
        let id: String
        let name: String
        let daysUntil: Int
        let date: Date
        let emoji: String
        let colorHex: String
        let isToday: Bool
    }

    /// Children whose birthday is today or within `window` days (default 7).
    static func upcomingBirthdays(
        children: [Child],
        from date: Date = Date(),
        window: Int = 7
    ) -> [Upcoming] {
        let calendar = Calendar.current
        return children.compactMap { child -> Upcoming? in
            guard let dob = child.dateOfBirth else { return nil }
            var comps = calendar.dateComponents([.month, .day], from: dob)
            comps.year = calendar.component(.year, from: date)
            guard var next = calendar.date(from: comps) else { return nil }
            if next < calendar.startOfDay(for: date) {
                comps.year = (comps.year ?? 0) + 1
                guard let advanced = calendar.date(from: comps) else { return nil }
                next = advanced
            }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: next)).day ?? 0
            guard days >= 0, days <= window else { return nil }
            return Upcoming(
                id: child.id,
                name: child.name,
                daysUntil: days,
                date: next,
                emoji: child.avatar.emoji,
                colorHex: child.avatar.colorHex,
                isToday: days == 0
            )
        }
        .sorted { $0.daysUntil < $1.daysUntil }
    }

    static func message(for item: Upcoming) -> String {
        if item.isToday {
            return "🎂 It's \(item.name)'s birthday today!"
        }
        if item.daysUntil == 1 {
            return "🎂 \(item.name)'s birthday is tomorrow"
        }
        return "🎂 \(item.name)'s birthday is in \(item.daysUntil) days"
    }
}
