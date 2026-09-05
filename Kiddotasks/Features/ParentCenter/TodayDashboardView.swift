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

    private var totals: LocalFamilyDataStore.TodayTotals {
        appState.store.todayTotals()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddotasksDesignTokens.Spacing.medium) {
                    header
                    statTiles
                    WeeklyStarsCard(series: appState.store.weeklyPointsSeries())
                    childProgress
                    pendingApprovalsCard
                    rewardRequestsCard
                }
                .padding(.horizontal, KiddotasksDesignTokens.Spacing.medium)
                .padding(.bottom, KiddotasksDesignTokens.Spacing.xLarge)
            }
            .background(KiddotasksDesignTokens.PageBackgrounds.parentPage.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Decline mission", isPresented: Binding(
                get: { rejectingCompletion != nil },
                set: { if !$0 { rejectingCompletion = nil } }
            )) {
                TextField("Reason (optional)", text: $rejectReason)
                Button("Decline", role: .destructive) {
                    if let completion = rejectingCompletion {
                        try? appState.store.rejectCompletion(completion.id, reason: rejectReason)
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
                        try? appState.store.approveCompletion(completion.id, message: approveMessage.isEmpty ? nil : approveMessage)
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
                        try? appState.store.approveClaim(claim.id, message: approveClaimMessage.isEmpty ? nil : approveClaimMessage)
                    }
                    approveClaimMessage = ""
                    approvingClaim = nil
                }
                Button("Cancel", role: .cancel) { approvingClaim = nil }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        FamilyBrandHeader(
            familyName: appState.currentFamily?.name ?? "Our family",
            subtitle: Date.now.formatted(date: .abbreviated, time: .omitted)
        ) {
            Button {
                appState.clearChildProfile()
                appState.interfaceOverride = .kids
            } label: {
                Image(systemName: "ipad.landscape")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(KiddotasksDesignTokens.Colors.primary.opacity(0.10)))
            }
            .buttonStyle(KiddoPressStyle())
            .accessibilityLabel("Open Kids Station")
        }
        .padding(.top, KiddotasksDesignTokens.Spacing.medium)
    }

    // MARK: Stat tiles

    private var statTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatTile(
                value: totals.pendingApprovals,
                label: "Missions to review",
                icon: "checkmark.seal.fill",
                color: Color(hex: "#F97316")
            )
            StatTile(
                value: totals.pendingRewardRequests,
                label: "Reward requests",
                icon: "gift.fill",
                color: Color(hex: "#EC4899")
            )
            StatTile(
                value: totals.starsEarned,
                label: "Stars earned today",
                icon: "star.fill",
                color: Color(hex: "#F59E0B")
            )
            StatTile(
                value: totals.missionsApproved,
                label: "Missions done today",
                icon: "party.popper.fill",
                color: KiddotasksDesignTokens.Colors.success
            )
        }
    }

    // MARK: Children progress

    private var childProgress: some View {
        SectionCard(title: "Kids today", icon: "figure.run", tint: KiddotasksDesignTokens.Colors.primary) {
            if appState.familyChildren.isEmpty {
                Text("Add a child in the Family tab to get started.")
                    .font(KiddotasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            } else {
                VStack(spacing: KiddotasksDesignTokens.Spacing.small) {
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
            tint: Color(hex: "#F97316")
        ) {
            let pending = appState.store.pendingCompletions()
            if pending.isEmpty {
                Text("No missions waiting. Nice! 🎉")
                    .font(KiddotasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            } else {
                VStack(spacing: KiddotasksDesignTokens.Spacing.small) {
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
            tint: KiddotasksDesignTokens.Colors.accent
        ) {
            let claims = appState.store.pendingClaims()
            if claims.isEmpty {
                Text("No reward requests right now.")
                    .font(KiddotasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            } else {
                VStack(spacing: KiddotasksDesignTokens.Spacing.small) {
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
        Color(hex: "#6366F1"), Color(hex: "#EC4899"), Color(hex: "#14B8A6"),
        Color(hex: "#F97316"), Color(hex: "#A855F7"), Color(hex: "#06B6D4")
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
            return KiddotasksDesignTokens.Colors.primary
        }
        return Self.palette[index % Self.palette.count]
    }

    var body: some View {
        SectionCard(title: "Stars this week", icon: "chart.bar.fill", tint: KiddotasksDesignTokens.Colors.primary) {
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
            .frame(height: 150)

            if names.count > 1 {
                HStack(spacing: 12) {
                    ForEach(names, id: \.self) { name in
                        HStack(spacing: 4) {
                            Circle().fill(color(for: name)).frame(width: 8, height: 8)
                            Text(name)
                                .font(KiddotasksDesignTokens.Typography.captionSmall)
                        }
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
            ChildAvatarView(avatar: child.avatar, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                Text("\(child.activePoints) ⭐ balance · \(missionsToday)/\(dueToday) missions today")
                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
                        .fill(task?.category.palette.accent ?? KiddotasksDesignTokens.Colors.primary)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(childName) · \(task?.name ?? "Mission")")
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                Text(completion.completedAt.formatted(date: .omitted, time: .shortened))
                    .font(KiddotasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
                .font(KiddotasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(KiddotasksDesignTokens.Colors.success))
        }
        .buttonStyle(KiddoPressStyle())
    }

    private var declineButton: some View {
        Button(action: onDecline) {
            Text("Decline")
                .font(KiddotasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(KiddotasksDesignTokens.Colors.error)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().strokeBorder(KiddotasksDesignTokens.Colors.error.opacity(0.5), lineWidth: 1.5)
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
                        .fill(KiddotasksDesignTokens.Colors.accent)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(childName) wants \(rewardName)")
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                Text(claim.claimedAt.formatted(date: .omitted, time: .shortened))
                    .font(KiddotasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            VStack(spacing: 6) {
                Button(action: onApprove) {
                    Text("Approve")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(KiddotasksDesignTokens.Colors.success))
                }
                .buttonStyle(KiddoPressStyle())
                Button(action: onDecline) {
                    Text("Decline")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.error)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().strokeBorder(KiddotasksDesignTokens.Colors.error.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .buttonStyle(KiddoPressStyle())
            }
        }
        .padding(.vertical, 4)
    }
}