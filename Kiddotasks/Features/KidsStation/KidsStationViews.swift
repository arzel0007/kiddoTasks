
import SwiftUI

struct ChildSelectionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Parent") {
                    appState.clearChildProfile()
                    appState.interfaceOverride = .parent
                }
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                Spacer()
                HStack(spacing: 8) {
                    KiddoTasksLogoMark(size: 26)
                    Text("Who's playing?")
                        .font(KiddoTasksDesignTokens.Typography.headingLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                }
                Spacer()
                Color.clear.frame(width: 48, height: 1)
            }
            .padding(.horizontal)

            if appState.familyChildren.isEmpty {
                VStack(spacing: 16) {
                    FloatingEmoji(emoji: "🧒", size: 72)
                    EmptyStateView(
                        emoji: "",
                        title: "No kids yet",
                        message: "Ask a parent to add a child in the Parent Center."
                    )
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(Array(appState.familyChildren.enumerated()), id: \.element.id) { index, child in
                        Button {
                            Haptic.light()
                            appState.selectChildProfile(child)
                        } label: {
                            VStack(spacing: 12) {
                                ChildAvatarView(avatar: child.avatar, size: 88, photoData: child.photoData)
                                Text(child.name)
                                    .font(KiddoTasksDesignTokens.Typography.titleMedium)
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                                PointsBadge(points: child.activePoints, compact: true)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .kiddotasksShadow(.large)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color(hex: child.avatar.colorHex).opacity(0.25), lineWidth: 2)
                            }
                        }
                        .buttonStyle(ExtraBouncyPressStyle())
                        .popIn(delay: Double(index) * 0.08)
                    }
                }
                .padding()
            }
            Spacer()
        }
        .padding(.top, 24)
        .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground)
    }
}

struct KidsStationView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

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
        }
        .tint(KiddoTasksDesignTokens.Colors.accent)
        .onChange(of: selectedTab) { _, _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                        VStack(spacing: 16) {
                            FloatingEmoji(emoji: "🎯", size: 72)
                            EmptyStateView(emoji: "", title: "All clear", message: "No missions for today.")
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(Array(missions.enumerated()), id: \.element.id) { index, task in
                                    Button {
                                        selectedTask = task
                                    } label: {
                                        MissionCard(
                                            task: task,
                                            completion: appState.store.todaysCompletion(taskId: task.id, childId: child.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .popIn(delay: Double(index) * 0.06)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky)
            .navigationTitle(child.map { "Hi, \($0.name)!" } ?? "Missions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Switch") { appState.clearChildProfile() }
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
                    .foregroundStyle(Color(hex: "#B45309"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: "#FEF3C7")))

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
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky)
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
            onFinish(true)
        } catch {
            appState.presentError(error)
        }
    }
}

struct CelebrationView: View {
    let task: KiddoTask
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Text(["🎉", "⭐", "✨", "🎊"][index % 4])
                        .font(.system(size: 22))
                        .offset(
                            x: cos(Double(index) / 8 * .pi * 2) * 112,
                            y: sin(Double(index) / 8 * .pi * 2) * 112
                        )
                        .opacity(0.9)
                }
                Text("🎉")
                    .font(.system(size: 104))
            }
            Text("Awesome!")
                .font(KiddoTasksDesignTokens.Typography.displayLarge)
            Text("You finished \(task.name)")
                .font(KiddoTasksDesignTokens.Typography.headingSmall)
                .multilineTextAlignment(.center)
            Text("+\(task.pointValue) ⭐")
                .font(KiddoTasksDesignTokens.Typography.pointsDisplay)
                .foregroundStyle(Color(hex: "#B45309"))
            Spacer()
            PrimaryButton(title: "Next mission", color: KiddoTasksDesignTokens.Colors.success) { onDone() }
        }
        .padding(24)
        .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop)
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
                        VStack(spacing: 16) {
                            FloatingEmoji(emoji: "🎁", size: 72)
                            EmptyStateView(emoji: "", title: "Shop is empty", message: "Parents can add rewards.")
                        }
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
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop)
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
                message = "You got \(reward.name)!"
            } else {
                message = "Asked a parent for \(reward.name)."
            }
        } catch {
            message = error.localizedDescription
        }
    }
}

struct AchievementsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            let earned = appState.store.achievements.filter { $0.childId == appState.currentChildProfile?.id }
            Group {
                if earned.isEmpty {
                    VStack(spacing: 16) {
                        FloatingEmoji(emoji: "🏅", size: 72)
                        EmptyStateView(
                            emoji: "",
                            title: "No badges yet",
                            message: "Finish missions to earn badges."
                        )
                    }
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
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .kiddotasksShadow(.medium)
                                .popIn(delay: Double(index) * 0.08)
                            }
                        }
                        .padding()
                    }
                }
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground)
            .navigationTitle("Badges")
        }
    }
}
