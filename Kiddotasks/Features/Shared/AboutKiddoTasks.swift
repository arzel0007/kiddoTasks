import SwiftUI

/// About KiddoTasks — mission story shared by Family and Welcome.
enum KiddoAbout {
    static let title = "About KiddoTasks"
    static let tagline = "Growing capable kids, one task at a time."

    static let paragraphs: [String] = [
        "KiddoTasks was created to help children build the skills, habits, and confidence they need to become more independent.",
        "We believe chores are more than tasks on a checklist. They are opportunities for children to learn responsibility, practice good habits, contribute to the family, and gradually learn how to take care of themselves and the things around them.",
        "The points and rewards in KiddoTasks are simply tools to make that learning process more engaging and enjoyable. They give children something to work toward while helping them experience the connection between effort, responsibility, and achievement.",
        "But the goal is bigger than earning points.",
        "As children develop routines and good habits, we hope the rewards become less important—and the skills they gain become more valuable. What starts as “I did this because I want points” can eventually become “I can do this on my own.”",
        "Parents remain an essential part of that journey. KiddoTasks is designed to support parents, not replace them—giving families a simple way to encourage meaningful conversations about responsibility, effort, and why everyday tasks matter.",
    ]

    static let closing =
        "Because the greatest reward isn't the points children earn. It's the confidence, responsibility, and life skills they carry with them as they grow."

    static let signoff = "KiddoTasks — Growing capable kids, one task at a time."
}

/// Bottom-sheet body for the About story.
struct AboutKiddoTasksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KiddoSheetHeader(
                title: KiddoAbout.title,
                subtitle: KiddoAbout.tagline,
                onDismiss: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    ForEach(Array(KiddoAbout.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        Text(paragraph)
                            .font(
                                paragraph == "But the goal is bigger than earning points."
                                    ? KiddoTasksDesignTokens.Typography.titleSmall
                                    : KiddoTasksDesignTokens.Typography.bodyLarge
                            )
                            .foregroundStyle(
                                paragraph == "But the goal is bigger than earning points."
                                    ? KiddoTasksDesignTokens.Colors.text
                                    : KiddoTasksDesignTokens.Colors.textSecondary
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Paragraph \(index + 1)")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(KiddoAbout.closing)
                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(KiddoAbout.signoff)
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                    }
                    .padding(KiddoTasksDesignTokens.Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous)
                            .fill(KiddoTasksDesignTokens.Colors.primaryLight)
                    )

                    PrimaryButton(title: "Close") { dismiss() }
                }
                .padding(.horizontal, KiddoTasksDesignTokens.Spacing.large)
                .padding(.bottom, KiddoTasksDesignTokens.Spacing.xLarge)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KiddoTasksDesignTokens.Colors.surface)
    }
}
