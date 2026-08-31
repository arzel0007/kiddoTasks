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
                .font(KiddotasksDesignTokens.Typography.captionLarge)
                Spacer()
                Text("Who's playing?")
                    .font(KiddotasksDesignTokens.Typography.headingLarge)
                Spacer()
                Color.clear.frame(width: 48, height: 1)
            }
            .padding(.horizontal)

            if appState.familyChildren.isEmpty {
                EmptyStateView(
                    emoji: "🧒",
                    title: "No kids yet",
                    message: "Ask a parent to add a child in the Parent Center."
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(appState.familyChildren) { child in
                        Button {
                            appState.selectChildProfile(child)
                        } label: {
                            VStack(spacing: 12) {
                                ChildAvatarView(avatar: child.avatar, size: 88)
                                Text(child.name)
                                    .font(KiddotasksDesignTokens.Typography.titleMedium)
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                                PointsBadge(points: child.activePoints, compact: true)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .kiddotasksShadow(.medium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            Spacer()
        }
        .padding(.top, 24)
        .background(KiddotasksDesignTokens.Colors.kidsBackground2.ignoresSafeArea())
    }
}

struct KidsStationView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            MissionsView()
                .tabItem { Label("Missions", systemImage: "star.fill") }
            RewardShopView()
                .tabItem { Label("Shop", systemImage: "gift.fill") }
            AchievementsView()
                .tabItem { Label("Badges", systemImage: "medal.fill") }
        }
        .tint(KiddotasksDesignTokens.Colors.primary)
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
                        EmptyStateView(emoji: "🎯", title: "All clear", message: "No missions for today.")
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(missions) { task in
                                    Button {
                                        selectedTask = task
                                    } label: {
                                        MissionCard(
                                            task: task,
                                            completion: appState.store.todaysCompletion(taskId: task.id, childId: child.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .background(KiddotasksDesignTokens.Colors.kidsBackground3.ignoresSafeArea())
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
                    .font(.system(size: 56))
                    .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
                Text(task.name)
                    .font(KiddotasksDesignTokens.Typography.headingLarge)
                Text(task.description.isEmpty ? "You've got this!" : task.description)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                Text("Earn \(task.pointValue) stars")
                    .font(KiddotasksDesignTokens.Typography.titleMedium)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.success)

                if let existing {
                    Text("Latest submission: \(existing.status.displayName)")
                        .font(KiddotasksDesignTokens.Typography.bodyLarge)
                        .padding(.top, 8)
                    PrimaryButton(title: "Submit again") {
                        submitCompletion()
                    }
                } else {
                    PrimaryButton(title: "I did it!") {
                        submitCompletion()
                    }
                }
                Spacer()
            }
            .padding(24)
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
            Text("🎉")
                .font(.system(size: 96))
            Text("Awesome!")
                .font(KiddotasksDesignTokens.Typography.displayLarge)
            Text("You finished \(task.name)")
                .font(KiddotasksDesignTokens.Typography.headingSmall)
                .multilineTextAlignment(.center)
            Text("+\(task.pointValue) ⭐")
                .font(KiddotasksDesignTokens.Typography.pointsDisplay)
                .foregroundStyle(KiddotasksDesignTokens.Colors.success)
            Spacer()
            PrimaryButton(title: "Next mission") { onDone() }
        }
        .padding(24)
        .background(KiddotasksDesignTokens.Colors.kidsBackground1.ignoresSafeArea())
    }
}

struct RewardShopView: View {
    @Environment(AppState.self) private var appState
    @State private var message: String?

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
                        EmptyStateView(emoji: "🎁", title: "Shop is empty", message: "Parents can add rewards.")
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                ForEach(shop) { reward in
                                    Button {
                                        claim(reward, child: child)
                                    } label: {
                                        RewardShopCard(reward: reward, points: child.activePoints)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!reward.canAfford(with: child.activePoints))
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .background(KiddotasksDesignTokens.Colors.kidsBackground4.ignoresSafeArea())
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
                    EmptyStateView(emoji: "🏅", title: "No badges yet", message: "Finish missions to earn badges.")
                } else {
                    List(earned) { achievement in
                        HStack(spacing: 12) {
                            Text(achievement.type.emoji).font(.largeTitle)
                            VStack(alignment: .leading) {
                                Text(achievement.type.displayName)
                                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                                Text(achievement.type.description)
                                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Badges")
        }
    }
}
