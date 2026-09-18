import Foundation

/// Short lines Arz says when tapped. Cycled so repeats stay fun.
enum ArzPhrases {
    struct Line: Equatable {
        let title: String
        let body: String
    }

    static let all: [Line] = [
        Line(title: "Hi! I'm Arz 👋", body: "I'm here to help you and the kids stay on track!"),
        Line(title: "Hey there! 👋", body: "I'm Arz — your KiddoTasks buddy."),
        Line(title: "What's up? ⭐", body: "Missions, stars, and high-fives. Let's go!"),
        Line(title: "Hi friend! 😊", body: "Tap me anytime you want a little cheer."),
        Line(title: "Arz here! ✨", body: "Ready to help your family stay on track."),
    ]

    private static var index = 0

    /// Next phrase in rotation (MainActor UI).
    @MainActor
    static func next() -> Line {
        let line = all[index % all.count]
        index += 1
        return line
    }

    /// Personalized greeting for a kid in Kids Station.
    @MainActor
    static func kidHello(name: String) -> Line {
        Line(
            title: "Hi \(name)! 👋",
            body: "Ready to log your chores for today?"
        )
    }

    /// Alternate kid lines used after the first hello.
    @MainActor
    static func kidFollowUp(name: String) -> Line {
        let options = [
            Line(title: "Let's go, \(name)! ⭐", body: "Tap a mission when you're done."),
            Line(title: "Nice to see you, \(name)!", body: "I'll cheer when you earn stars."),
            Line(title: "\(name), you've got this! 💪", body: "One chore at a time."),
        ]
        let line = options[index % options.count]
        index += 1
        return line
    }
}
