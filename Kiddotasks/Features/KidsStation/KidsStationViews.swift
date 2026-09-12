
import SwiftUI

struct ChildSelectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Soft-previewed child (press/focus) — drives the page wash before enter.
    @State private var previewChild: Child?

    private var pageTheme: ChildPlayerTheme {
        ChildPlayerTheme.theme(for: previewChild, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            // Flat base + accent wash (two solids, no gradient).
            KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground
            if let previewChild {
                Color(hex: previewChild.avatar.colorHex)
                    .opacity(colorScheme == .dark ? 0.22 : 0.18)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack(spacing: 20) {
                header

                if appState.familyChildren.isEmpty {
                    emptyState
                } else {
                    playerGrid
                }

                Spacer(minLength: 8)
            }
            .padding(.top, 20)
            .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.15) : KiddoTasksDesignTokens.Animation.standard,
            value: previewChild?.id
        )
    }

    private var header: some View {
        HStack {
            Button {
                appState.clearChildProfile()
                appState.interfaceOverride = .parent
            } label: {
                Text("Parent")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.85))
                    )
            }
            .buttonStyle(KiddoPressStyle())
            .accessibilityLabel("Back to Parent Center")

            Spacer()

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    KiddoTasksLogoMark(size: 24)
                    Text("Who's playing?")
                        .font(KiddoTasksDesignTokens.Typography.headingLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                }
                Text(previewSubtitle)
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .opacity(previewChild == nil ? 0.7 : 1)
            }

            Spacer()

            Color.clear.frame(width: 64, height: 1)
        }
    }

    private var previewSubtitle: String {
        if let previewChild {
            return "Tap to start as \(previewChild.name)"
        }
        return "Pick your face to start"
    }

    private var emptyState: some View {
        EmptyStateView(
            emoji: "🧒",
            title: "No kids yet",
            message: "Ask a parent to add a child in the Parent Center."
        )
        .frame(maxWidth: .infinity)
    }

    private var playerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(Array(appState.familyChildren.enumerated()), id: \.element.id) { index, child in
                PlayerCard(
                    child: child,
                    isPreviewed: previewChild?.id == child.id,
                    colorScheme: colorScheme
                ) {
                    // Brief wash, then enter — feels like stepping into their space.
                    previewChild = child
                    Haptic.medium()
                    let delay: UInt64 = reduceMotion ? 0 : 220_000_000
                    Task { @MainActor in
                        if delay > 0 {
                            try? await Task.sleep(nanoseconds: delay)
                        }
                        appState.selectChildProfile(child)
                    }
                }
                .buttonStyle(ExtraBouncyPressStyle())
                .popIn(delay: reduceMotion ? 0 : Double(index) * 0.06)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if previewChild?.id != child.id {
                                withAnimation {
                                    previewChild = child
                                }
                            }
                        }
                )
            }
        }
    }
}

/// Large kid-facing player tile with accent wash + strong identity.
private struct PlayerCard: View {
    let child: Child
    let isPreviewed: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    private var accent: Color { Color(hex: child.avatar.colorHex) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ChildAvatarView(avatar: child.avatar, size: 84, photoData: child.photoData, photoURL: child.photoURL)
                    .scaleEffect(isPreviewed ? 1.05 : 1)

                Text(child.name)
                    .font(KiddoTasksDesignTokens.Typography.titleMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                PointsBadge(points: child.activePoints, compact: true)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(isPreviewed ? accent.opacity(colorScheme == .dark ? 0.28 : 0.20) : KiddoTasksDesignTokens.Colors.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        isPreviewed ? accent.opacity(0.65) : accent.opacity(0.28),
                        lineWidth: isPreviewed ? 3 : 2
                    )
            )
            .kiddotasksShadow(isPreviewed ? .large : .medium)
            .scaleEffect(isPreviewed ? 1.02 : 1)
            .animation(
                .spring(response: 0.32, dampingFraction: 0.72),
                value: isPreviewed
            )
        }
        .accessibilityLabel("\(child.name), \(child.activePoints) stars")
        .accessibilityHint("Starts Kids Station for \(child.name)")
    }
}

struct KidsStationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 0
    @State private var tabContentID = 0

    private var child: Child? {
        guard let selected = appState.currentChildProfile else { return nil }
        return appState.child(id: selected.id)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MissionsView()
                .tabItem { Label("Missions", systemImage: "star.fill") }
                .tag(0)
            RewardShopView()
                .tabItem { Label("Shop", systemImage: "gift.fill") }
                .tag(1)
            AchievementsView()
                .tabItem { Label("Badges", systemImage: "medal.fill") }
                .tag(2)
            if appState.currentFamily?.settings.enableMiniGames ?? true {
                BasketballGameView()
                    .tabItem { Label("Play", systemImage: "basketball.fill") }
                    .tag(3)
            }
        }
        .tint(child?.playerAccentColor ?? KiddoTasksDesignTokens.Colors.accent)
        .onChange(of: selectedTab) { _, _ in
            if !reduceMotion { Haptic.light() }
            tabContentID += 1
        }
    }
}

struct MissionsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTask: KiddoTask?
    @State private var celebration: KiddoTask?

    var child: Child? {
        guard let selected = appState.currentChildProfile else { return nil }
        return appState.child(id: selected.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let child {
                    let missions = appState.store.tasksForChild(child.id)
                    if missions.isEmpty {
                        EmptyStateView(
                            emoji: "🎯",
                            title: "All clear",
                            message: "No missions for today. Great job!"
                        )
                    } else {
                        List {
                            ForEach(Array(missions.enumerated()), id: \.element.id) { index, task in
                                let completion = appState.store.todaysCompletion(taskId: task.id, childId: child.id)
                                Button {
                                    selectedTask = task
                                } label: {
                                    MissionCard(task: task, completion: completion)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(CardPressStyle())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if completion == nil || completion?.status == .rejected {
                                        Button {
                                            quickSubmit(task: task, child: child)
                                        } label: {
                                            Label("Done", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(KiddoTasksDesignTokens.Colors.success)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .kiddoChildPageBackground(child, base: KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky)
            .navigationTitle(child.map { "Hi, \($0.name)!" } ?? "Missions")
            .safeAreaInset(edge: .top, spacing: 0) {
                if let child, BirthdayReminder.upcomingBirthdays(children: [child]).first?.isToday == true {
                    Text("🎂 Happy birthday, \(child.name)!")
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(KiddoTasksDesignTokens.Colors.rewardLight)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Switch") {
                        // Leaving the active kid profile; if this was a PIN-only
                        // session with no parent account, lock back to Welcome.
                        if appState.currentParent?.id == "kids-session" {
                            appState.lockKidsSession()
                        } else {
                            appState.clearChildProfile()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let child {
                        PointsBadge(points: child.activePoints, compact: true)
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                if let child {
                    TaskDetailView(task: task, child: child) { completed in
                        selectedTask = nil
                        if completed { celebration = task }
                    }
                }
            }
            .fullScreenCover(item: $celebration) { task in
                CelebrationView(task: task) { celebration = nil }
            }
        }
    }

    private func quickSubmit(task: KiddoTask, child: Child) {
        do {
            _ = try appState.store.submitCompletion(taskId: task.id, childId: child.id)
            let needsApproval = task.requiresParentApproval(using: appState.currentFamily?.settings ?? .default)
            if needsApproval {
                appState.toastSuccess("Sent to a parent — \(task.name)")
            } else {
                appState.toastSuccess("+\(task.pointValue) ★ \(task.name)!")
            }
        } catch {
            appState.toastError(error.localizedDescription)
        }
    }
}

struct TaskDetailView: View {
    @Environment(AppState.self) private var appState
    let task: KiddoTask
    let child: Child
    let onFinish: (Bool) -> Void

    var existing: TaskCompletion? {
        appState.store.todaysCompletion(taskId: task.id, childId: child.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: task.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 110, height: 110)
                    .background {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(task.category.palette.accent)
                    }
                Text(task.name)
                    .font(KiddoTasksDesignTokens.Typography.headingLarge)
                    .multilineTextAlignment(.center)
                Text(task.description.isEmpty ? "You've got this!" : task.description)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                Text("Earn \(task.pointValue) ⭐")
                    .font(KiddoTasksDesignTokens.Typography.titleMedium)
                    .foregroundStyle(Color(hex: "#365F8C"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: "#E8EEF4")))

                if let existing {
                    Text("Latest submission: \(existing.status.displayName)")
                        .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                        .padding(.top, 8)
                    if let message = existing.notes, !message.isEmpty {
                        Text("Parent said: \(message)")
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(KiddoTasksDesignTokens.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    PrimaryButton(
                        title: existing.status == .rejected ? "Try again" : "Submit again",
                        color: KiddoTasksDesignTokens.Colors.primary
                    ) {
                        submitCompletion()
                    }
                    .buttonStyle(ExtraBouncyPressStyle())
                } else {
                    PrimaryButton(
                        title: "I did it! 🎉",
                        color: KiddoTasksDesignTokens.Colors.success
                    ) {
                        submitCompletion()
                    }
                    .buttonStyle(ExtraBouncyPressStyle())
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .kiddoChildPageBackground(child, base: KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky)
            .navigationTitle("Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onFinish(false) }
                }
            }
        }
    }

    private func submitCompletion() {
        do {
            _ = try appState.store.submitCompletion(taskId: task.id, childId: child.id)
            appState.toastSuccess("Mission sent to a parent")
            onFinish(true)
        } catch {
            appState.toastError(error.localizedDescription)
            appState.presentError(error)
        }
    }
}

struct CelebrationView: View {
    let task: KiddoTask
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                if !reduceMotion {
                    ForEach(0..<8, id: \.self) { index in
                        Text(["🎉", "⭐", "✨", "🎊"][index % 4])
                            .font(.system(size: 22))
                            .offset(
                                x: cos(Double(index) / 8 * .pi * 2) * 112,
                                y: sin(Double(index) / 8 * .pi * 2) * 112
                            )
                            .opacity(0.9)
                    }
                }
                Text("🎉")
                    .font(.system(size: 104))
                    .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.7))
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.55),
                        value: appeared
                    )
            }
            Text("Awesome!")
                .font(KiddoTasksDesignTokens.Typography.displayLarge)
            Text("You finished \(task.name)")
                .font(KiddoTasksDesignTokens.Typography.headingSmall)
                .multilineTextAlignment(.center)
            Text("+\(task.pointValue) ⭐")
                .font(KiddoTasksDesignTokens.Typography.pointsDisplay)
                .foregroundStyle(Color(hex: "#365F8C"))
            Spacer()
            PrimaryButton(title: "Next mission", color: KiddoTasksDesignTokens.Colors.success) { onDone() }
        }
        .padding(24)
        .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop)
        .onAppear { appeared = true }
    }
}

struct RewardShopView: View {
    @Environment(AppState.self) private var appState
    @State private var message: String?
    @State private var wiggleTrigger = false

    var child: Child? {
        guard let selected = appState.currentChildProfile else { return nil }
        return appState.child(id: selected.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let child {
                    let shop = appState.store.rewards.filter { $0.isActive && $0.isEligibleFor(child.id) }
                    if shop.isEmpty {
                        EmptyStateView(
                            emoji: "🎁",
                            title: "Shop is empty",
                            message: "Parents can add rewards in the Parent Center."
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                ForEach(Array(shop.enumerated()), id: \.element.id) { index, reward in
                                    Button {
                                        claim(reward, child: child)
                                    } label: {
                                        ZStack {
                                            RewardShopCard(reward: reward, points: child.activePoints)
                                            if reward.canAfford(with: child.activePoints) {
                                                SparkleOverlay(color: KiddoTasksDesignTokens.KidsColors.sunshine)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!reward.canAfford(with: child.activePoints))
                                    .wiggle(trigger: wiggleTrigger && reward.canAfford(with: child.activePoints))
                                    .popIn(delay: Double(index) * 0.06)
                                    .onAppear {
                                        if reward.canAfford(with: child.activePoints) {
                                            wiggleTrigger = true
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .kiddoChildPageBackground(child, base: KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop)
            .navigationTitle("Reward shop")
            .alert("Shop", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func claim(_ reward: Reward, child: Child) {
        do {
            let claim = try appState.store.claimReward(rewardId: reward.id, childId: child.id)
            if claim.status == .approved {
                appState.toastSuccess("You got \(reward.name)!")
            } else {
                appState.toastSuccess("Asked a parent for \(reward.name)")
            }
        } catch {
            appState.toastError(error.localizedDescription)
        }
    }
}

struct AchievementsView: View {
    @Environment(AppState.self) private var appState

    private var child: Child? {
        guard let selected = appState.currentChildProfile else { return nil }
        return appState.child(id: selected.id)
    }

    var body: some View {
        NavigationStack {
            let earned = appState.store.achievements.filter { $0.childId == appState.currentChildProfile?.id }
            Group {
                if earned.isEmpty {
                    EmptyStateView(
                        emoji: "🏅",
                        title: "No badges yet",
                        message: "Finish missions to earn badges."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(Array(earned.enumerated()), id: \.element.id) { index, achievement in
                                VStack(spacing: 10) {
                                    Text(achievement.type.emoji)
                                        .font(.system(size: 44))
                                        .frame(width: 76, height: 76)
                                        .background(Circle().fill(KiddoTasksDesignTokens.KidsColors.sunshine))
                                    Text(achievement.type.displayName)
                                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                                    Text(achievement.type.description)
                                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(KiddoTasksDesignTokens.Colors.surfaceCard)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .kiddotasksShadow(.medium)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(
                                            (child?.playerAccentColor ?? KiddoTasksDesignTokens.KidsColors.sunshine)
                                                .opacity(0.20),
                                            lineWidth: 1.5
                                        )
                                }
                                .popIn(delay: Double(index) * 0.08)
                            }
                        }
                        .padding()
                    }
                }
            }
            .kiddoChildPageBackground(child, base: KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground)
            .navigationTitle("Badges")
        }
    }
}
