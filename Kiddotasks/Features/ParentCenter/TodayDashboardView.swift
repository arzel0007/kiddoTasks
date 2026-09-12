import SwiftUI
import Charts

/// The Today tab: branded header, metric tiles, a weekly stars chart, per-child
/// progress, and the pending approval queues.
struct TodayDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var rejectReason = ""
    @State private var rejectingCompletion: TaskCompletion?
    @State private var approveMessage = ""
    @State private var approvingCompletion: TaskCompletion?
    @State private var approveClaimMessage = ""
    @State private var approvingClaim: RewardClaim?

    /// Aggregates recomputed only when the store revision changes — avoids
    /// scanning transactions twice on every unrelated body pass.
    @State private var totals = LocalFamilyDataStore.TodayTotals(
        starsEarned: 0,
        missionsApproved: 0,
        pendingApprovals: 0,
        pendingRewardRequests: 0,
        tasksDueToday: 0
    )
    @State private var weeklySeries: [LocalFamilyDataStore.DailyPoints] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    header
                    birthdayBanner
                    statTiles
                    WeeklyStarsCard(series: weeklySeries)
                    childProgress
                    pendingApprovalsCard
                    rewardRequestsCard
                }
                .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
                .padding(.bottom, KiddoTasksDesignTokens.Spacing.xLarge)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if appState.isLoading {
                    VStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonListRow()
                        }
                    }
                    .padding()
                }
            }
            .onAppear(perform: recomputeAggregates)
            .onChange(of: appState.store.dataRevision) { _, _ in
                recomputeAggregates()
            }
            .alert("Decline mission", isPresented: Binding(
                get: { rejectingCompletion != nil },
                set: { if !$0 { rejectingCompletion = nil } }
            )) {
                TextField("Reason (optional)", text: $rejectReason)
                Button("Decline", role: .destructive) {
                    if let completion = rejectingCompletion {
                        do {
                            try appState.store.rejectCompletion(completion.id, reason: rejectReason)
                            appState.toastInfo("Mission declined")
                        } catch {
                            appState.toastError(error.localizedDescription)
                        }
                    }
                    rejectReason = ""
                    rejectingCompletion = nil
                }
                Button("Cancel", role: .cancel) { rejectingCompletion = nil }
            }
            .alert("Approve mission", isPresented: Binding(
                get: { approvingCompletion != nil },
                set: { if !$0 { approvingCompletion = nil } }
            )) {
                TextField("Message for child (optional)", text: $approveMessage)
                Button("Approve") {
                    if let completion = approvingCompletion {
                        do {
                            try appState.store.approveCompletion(completion.id, message: approveMessage.isEmpty ? nil : approveMessage)
                            appState.toastSuccess("Mission approved")
                        } catch {
                            appState.toastError(error.localizedDescription)
                        }
                    }
                    approveMessage = ""
                    approvingCompletion = nil
                }
                Button("Cancel", role: .cancel) { approvingCompletion = nil }
            }
            .alert("Approve reward", isPresented: Binding(
                get: { approvingClaim != nil },
                set: { if !$0 { approvingClaim = nil } }
            )) {
                TextField("Message for child (optional)", text: $approveClaimMessage)
                Button("Approve") {
                    if let claim = approvingClaim {
                        do {
                            try appState.store.approveClaim(claim.id, message: approveClaimMessage.isEmpty ? nil : approveClaimMessage)
                            appState.toastSuccess("Reward approved")
                        } catch {
                            appState.toastError(error.localizedDescription)
                        }
                    }
                    approveClaimMessage = ""
                    approvingClaim = nil
                }
                Button("Cancel", role: .cancel) { approvingClaim = nil }
            }
        }
    }

    private func recomputeAggregates() {
        totals = appState.store.todayTotals()
        weeklySeries = appState.store.weeklyPointsSeries()
    }

    // MARK: Birthday banner

    private var birthdayBanner: some View {
        let birthdays = BirthdayReminder.upcomingBirthdays(children: appState.familyChildren)
        let weekBonuses = appState.familyChildren.compactMap { child -> WeekBonus.Status? in
            let s = WeekBonus.status(
                child: child,
                completions: appState.store.completions,
                tasks: appState.store.tasks,
                settings: appState.store.family?.settings ?? .default
            )
            return s.isComplete ? s : nil
        }
        return Group {
            if !birthdays.isEmpty || !weekBonuses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(weekBonuses, id: \.childId) { bonus in
                        HStack(spacing: 12) {
                            Text("🏆")
                                .font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(bonus.title) — \(bonus.childName)")
                                    .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                Text("Completed missions every day this week")
                                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.successLight)
                        }
                    }
                    ForEach(birthdays) { b in
                        HStack(spacing: 12) {
                            Text("🎂")
                                .font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.isToday ? "Happy birthday, \(b.name)!" : BirthdayReminder.message(for: b))
                                    .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                Text(b.isToday ? "Make their day special" : "Coming up soon")
                                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.rewardLight)
                        }
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        FamilyBrandHeader(
            familyName: appState.currentFamily?.name ?? "Our family",
            subtitle: Date.now.formatted(date: .abbreviated, time: .omitted),
            familyPhotoData: appState.currentFamily?.photoData
        ) {
            Button {
                appState.clearChildProfile()
                appState.interfaceOverride = .kids
            } label: {
                Image(systemName: "ipad.landscape")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(KiddoTasksDesignTokens.Colors.primary.opacity(0.10)))
            }
            .buttonStyle(KiddoPressStyle())
            .accessibilityLabel("Open Kids Station")
        }
        .padding(.top, KiddoTasksDesignTokens.Spacing.medium)
    }

    // MARK: Stat tiles

    private var statTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatTile(
                value: totals.pendingApprovals,
                label: "Missions to review",
                icon: "checkmark.seal.fill",
                color: KiddoTasksDesignTokens.Colors.primary
            )
            StatTile(
                value: totals.pendingRewardRequests,
                label: "Reward requests",
                icon: "gift.fill",
                color: KiddoTasksDesignTokens.Colors.reward,
                tinted: true
            )
            StatTile(
                value: totals.starsEarned,
                label: "Stars earned today",
                icon: "star.fill",
                color: KiddoTasksDesignTokens.Colors.primaryMuted
            )
            StatTile(
                value: totals.missionsApproved,
                label: "Missions done today",
                icon: "checkmark.circle.fill",
                color: KiddoTasksDesignTokens.Colors.success,
                tinted: true
            )
        }
    }

    // MARK: Children progress

    private var childProgress: some View {
        SectionCard(title: "Kids today", icon: "figure.run", tint: KiddoTasksDesignTokens.Colors.primary) {
            if appState.familyChildren.isEmpty {
                EmptyStateView(
                    emoji: "👋",
                    title: "Add your kids",
                    message: "Create child profiles in the Family tab so missions can be assigned.",
                    actionTitle: "Got it"
                ) {
                    appState.toastInfo("Open the Family tab to add kids")
                }
                .frame(minHeight: 180)
            } else {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
                    ForEach(appState.familyChildren) { child in
                        ChildProgressRow(child: child, store: appState.store)
                    }
                }
            }
        }
    }

    // MARK: Pending approvals

    private var pendingApprovalsCard: some View {
        SectionCard(
            title: totals.pendingApprovals > 0
                ? "Waiting for approval (\(totals.pendingApprovals))"
                : "Waiting for approval",
            icon: "checkmark.seal.fill",
            tint: KiddoTasksDesignTokens.Colors.primary
        ) {
            let pending = appState.store.pendingCompletions()
            if pending.isEmpty {
                EmptyListHint(
                    emoji: "✨",
                    title: "No missions waiting. Nice!"
                )
            } else {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
                    ForEach(pending) { completion in
                        PendingCompletionRow(
                            completion: completion,
                            childName: appState.child(id: completion.childId)?.name ?? "Child",
                            task: appState.task(id: completion.taskId),
                            onApprove: { approvingCompletion = completion },
                            onDecline: { rejectingCompletion = completion }
                        )
                    }
                }
            }
        }
    }

    // MARK: Reward requests

    private var rewardRequestsCard: some View {
        SectionCard(
            title: totals.pendingRewardRequests > 0
                ? "Reward requests (\(totals.pendingRewardRequests))"
                : "Reward requests",
            icon: "gift.fill",
            tint: KiddoTasksDesignTokens.Colors.accent
        ) {
            let claims = appState.store.pendingClaims()
            if claims.isEmpty {
                EmptyListHint(
                    emoji: "🎁",
                    title: "No reward requests right now."
                )
            } else {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
                    ForEach(claims) { claim in
                        PendingClaimRow(
                            claim: claim,
                            childName: appState.child(id: claim.childId)?.name ?? "Child",
                            rewardName: appState.reward(id: claim.rewardId)?.name ?? "Reward",
                            onApprove: { approvingClaim = claim },
                            onDecline: { try? appState.store.rejectClaim(claim.id, reason: "Not now") }
                        )
                    }
                }
            }
        }
    }
}

/// Weekly stars chart (Swift Charts), stacked per child with a legend.
struct WeeklyStarsCard: View {
    let series: [LocalFamilyDataStore.DailyPoints]

    private static let palette: [Color] = [
        Color(hex: "#3978A8"), Color(hex: "#6F9FBD"), Color(hex: "#3F8B70"),
        Color(hex: "#D59A3A"), Color(hex: "#8B99A8"), Color(hex: "#285B82")
    ]

    private var names: [String] {
        var seen: [String] = []
        for point in series where !seen.contains(point.childName) {
            seen.append(point.childName)
        }
        return seen
    }

    private func color(for name: String) -> Color {
        guard let index = names.firstIndex(of: name) else {
            return KiddoTasksDesignTokens.Colors.primary
        }
        return Self.palette[index % Self.palette.count]
    }

    var body: some View {
        SectionCard(title: "Stars this week", icon: "chart.bar.fill", tint: KiddoTasksDesignTokens.Colors.primary) {
            Chart(series) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Stars", point.stars)
                )
                .foregroundStyle(by: .value("Child", point.childName))
                .cornerRadius(3)
            }
            .chartForegroundStyleScale(domain: names, range: names.map(color(for:)))
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 150)

            if names.count > 1 {
                HStack(spacing: 12) {
                    ForEach(names, id: \.self) { name in
                        HStack(spacing: 4) {
                            Circle().fill(color(for: name)).frame(width: 8, height: 8)
                            Text(name)
                                .font(KiddoTasksDesignTokens.Typography.captionSmall)
                        }
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

/// Per-child summary row: avatar, balance, today's progress bar.
struct ChildProgressRow: View {
    let child: Child
    let store: LocalFamilyDataStore

    private var missionsToday: Int { store.missionsApproved(byChild: child.id) }
    private var dueToday: Int {
        store.tasks.filter { $0.isActive && $0.isAssignedTo(child.id) && $0.isDue() }.count
    }
    private var progress: Double {
        dueToday == 0 ? 1 : Double(min(missionsToday, dueToday)) / Double(dueToday)
    }

    var body: some View {
        HStack(spacing: 12) {
            ChildAvatarView(avatar: child.avatar, size: 44, photoData: child.photoData)
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                Text("\(child.activePoints) ⭐ balance · \(missionsToday)/\(dueToday) missions today")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                ProgressView(value: progress)
                    .tint(Color(hex: child.avatar.colorHex))
            }
            Spacer()
            PointsBadge(points: store.starsEarned(byChild: child.id), compact: true)
        }
        .padding(.vertical, 4)
    }
}

/// One pending mission waiting for a parent decision.
struct PendingCompletionRow: View {
    let completion: TaskCompletion
    let childName: String
    let task: KiddoTask?
    var onApprove: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task?.icon ?? "checkmark.circle.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(task?.category.palette.accent ?? KiddoTasksDesignTokens.Colors.primary)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(childName) · \(task?.name ?? "Mission")")
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                Text(completion.completedAt.formatted(date: .omitted, time: .shortened))
                    .font(KiddoTasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            VStack(spacing: 6) {
                approveButton
                declineButton
            }
        }
        .padding(.vertical, 4)
    }

    private var approveButton: some View {
        Button(action: onApprove) {
            Text("Approve")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.success))
        }
        .buttonStyle(KiddoPressStyle())
    }

    private var declineButton: some View {
        Button(action: onDecline) {
            Text("Decline")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().strokeBorder(KiddoTasksDesignTokens.Colors.error.opacity(0.5), lineWidth: 1.5)
                )
        }
        .buttonStyle(KiddoPressStyle())
    }
}

/// One pending reward request waiting for a parent decision.
struct PendingClaimRow: View {
    let claim: RewardClaim
    let childName: String
    let rewardName: String
    var onApprove: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KiddoTasksDesignTokens.Colors.accent)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(childName) wants \(rewardName)")
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                Text(claim.claimedAt.formatted(date: .omitted, time: .shortened))
                    .font(KiddoTasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            VStack(spacing: 6) {
                Button(action: onApprove) {
                    Text("Approve")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(KiddoTasksDesignTokens.Colors.success))
                }
                .buttonStyle(KiddoPressStyle())
                Button(action: onDecline) {
                    Text("Decline")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().strokeBorder(KiddoTasksDesignTokens.Colors.error.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .buttonStyle(KiddoPressStyle())
            }
        }
        .padding(.vertical, 4)
    }
}