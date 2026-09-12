import Foundation

/// Full-week completion → celebration (e.g. “Full week! Ice cream night”).
enum WeekBonus {
    struct Status: Equatable {
        let childId: String
        let childName: String
        let daysWithWork: Int
        let totalDays: Int
        let isComplete: Bool
        let title: String
    }

    /// Days since week start (settings.weekStartsOn: 1=Mon … 7=Sun) where the
    /// child had at least one approved completion.
    static func status(
        child: Child,
        completions: [TaskCompletion],
        tasks: [KiddoTask],
        settings: FamilySettings,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Status {
        var cal = calendar
        cal.firstWeekday = max(1, min(7, settings.weekStartsOn))
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else {
            return Status(
                childId: child.id,
                childName: child.name,
                daysWithWork: 0,
                totalDays: 7,
                isComplete: false,
                title: settings.weekBonusTitle
            )
        }

        let approved = completions.filter {
            $0.childId == child.id && $0.status == .approved
        }

        var days = Set<Int>()
        for completion in approved {
            let when = completion.approvedAt ?? completion.completedAt
            if interval.contains(when) {
                days.insert(cal.component(.weekday, from: when))
            }
        }

        // Count elapsed days of this week (don’t require future days).
        let elapsed = cal.dateComponents([.day], from: interval.start, to: now).day ?? 0
        let daysElapsed = min(7, max(1, elapsed + 1))
        // Full week only when the week is over and every day had activity.
        let isComplete = daysElapsed >= 7 && days.count >= 7

        return Status(
            childId: child.id,
            childName: child.name,
            daysWithWork: days.count,
            totalDays: 7,
            isComplete: isComplete,
            title: settings.weekBonusTitle
        )
    }

    /// True once this week’s bonus should be celebrated for the first time.
    static func shouldCelebrate(
        status: Status,
        alreadyCelebratedThisWeek: Bool
    ) -> Bool {
        status.isComplete && !alreadyCelebratedThisWeek
    }
}
