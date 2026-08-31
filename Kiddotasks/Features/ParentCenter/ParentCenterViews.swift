import SwiftUI

struct ParentControlCenter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            ApprovalHomeView()
                .tabItem { Label("Today", systemImage: "checkmark.seal.fill") }
            TaskListView()
                .tabItem { Label("Tasks", systemImage: "list.bullet.clipboard") }
            RewardListView()
                .tabItem { Label("Rewards", systemImage: "gift") }
            FamilyView()
                .tabItem { Label("Family", systemImage: "house.fill") }
            ActivityView()
                .tabItem { Label("History", systemImage: "clock") }
        }
        .tint(KiddotasksDesignTokens.Colors.primary)
    }
}

struct ApprovalHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var rejectReason = ""
    @State private var rejectingCompletion: TaskCompletion?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        appState.interfaceOverride = .kids
                        appState.clearChildProfile()
                    } label: {
                        Label("Open Kids Station", systemImage: "ipad")
                    }
                }

                Section("Waiting for approval") {
                    let pending = appState.store.pendingCompletions()
                    if pending.isEmpty {
                        Text("No missions waiting.")
                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                    } else {
                        ForEach(pending) { completion in
                            completionRow(completion)
                        }
                    }
                }

                Section("Reward requests") {
                    let claims = appState.store.pendingClaims()
                    if claims.isEmpty {
                        Text("No reward requests.")
                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                    } else {
                        ForEach(claims) { claim in
                            claimRow(claim)
                        }
                    }
                }
            }
            .navigationTitle(appState.currentFamily?.name ?? "Today")
            .alert("Reject mission", isPresented: Binding(
                get: { rejectingCompletion != nil },
                set: { if !$0 { rejectingCompletion = nil } }
            )) {
                TextField("Reason", text: $rejectReason)
                Button("Reject", role: .destructive) {
                    if let completion = rejectingCompletion {
                        try? appState.store.rejectCompletion(completion.id, reason: rejectReason)
                    }
                    rejectReason = ""
                    rejectingCompletion = nil
                }
                Button("Cancel", role: .cancel) { rejectingCompletion = nil }
            }
        }
    }

    @ViewBuilder
    private func completionRow(_ completion: TaskCompletion) -> some View {
        let childName = appState.child(id: completion.childId)?.name ?? "Child"
        let taskName = appState.task(id: completion.taskId)?.name ?? "Task"
        VStack(alignment: .leading, spacing: 8) {
            Text("\(childName) · \(taskName)")
                .font(KiddotasksDesignTokens.Typography.titleSmall)
            HStack {
                Button("Approve") {
                    try? appState.store.approveCompletion(completion.id)
                }
                .buttonStyle(.borderedProminent)
                Button("Reject", role: .destructive) {
                    rejectingCompletion = completion
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func claimRow(_ claim: RewardClaim) -> some View {
        let childName = appState.child(id: claim.childId)?.name ?? "Child"
        let rewardName = appState.reward(id: claim.rewardId)?.name ?? "Reward"
        VStack(alignment: .leading, spacing: 8) {
            Text("\(childName) wants \(rewardName)")
                .font(KiddotasksDesignTokens.Typography.titleSmall)
            HStack {
                Button("Approve") {
                    try? appState.store.approveClaim(claim.id)
                }
                .buttonStyle(.borderedProminent)
                Button("Reject", role: .destructive) {
                    try? appState.store.rejectClaim(claim.id, reason: "Not now")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TaskListView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List(appState.store.tasks.filter(\.isActive)) { task in
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name).font(KiddotasksDesignTokens.Typography.titleSmall)
                    Text("\(task.pointValue) ⭐ · \(task.recurrence.type.displayName)")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
                .swipeActions {
                    Button("Archive", role: .destructive) {
                        try? appState.store.archiveTask(task.id)
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showEditor) {
                TaskEditorView()
            }
        }
    }
}

struct TaskEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var points = 10
    @State private var category = TaskCategory.household
    @State private var recurrence = RecurrenceType.daily
    @State private var approvalBehavior = TaskApprovalBehavior.useFamilyDefault
    @State private var assigned: Set<String> = []
    @State private var icon = "checkmark.circle.fill"

    private let icons = [
        "checkmark.circle.fill", "bed.double.fill", "fork.knife", "trash.fill",
        "book.fill", "figure.run", "mouth.fill", "tshirt.fill", "pawprint.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                Stepper("Stars: \(points)", value: $points, in: 1...100)
                Picker("Category", selection: $category) {
                    ForEach(TaskCategory.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                Picker("Repeat", selection: $recurrence) {
                    ForEach(RecurrenceType.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                Picker("Approval", selection: $approvalBehavior) {
                    ForEach(TaskApprovalBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                Picker("Icon", selection: $icon) {
                    ForEach(icons, id: \.self) { item in
                        Label(item, systemImage: item).tag(item)
                    }
                }
                Section("Assign to") {
                    ForEach(appState.familyChildren) { child in
                        Toggle(child.name, isOn: Binding(
                            get: { assigned.contains(child.id) },
                            set: { on in
                                if on { assigned.insert(child.id) } else { assigned.remove(child.id) }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("New task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try appState.store.addTask(
                                name: name,
                                description: description,
                                icon: icon,
                                category: category,
                                pointValue: points,
                                approvalBehavior: approvalBehavior,
                                assignedChildIds: Array(assigned),
                                recurrence: TaskRecurrence(type: recurrence)
                            )
                            dismiss()
                        } catch {
                            appState.presentError(error)
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct RewardListView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List(appState.store.rewards.filter(\.isActive)) { reward in
                VStack(alignment: .leading) {
                    Text(reward.name).font(KiddotasksDesignTokens.Typography.titleSmall)
                    Text("\(reward.pointCost) ⭐")
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showEditor) { RewardEditorView() }
        }
    }
}

struct RewardEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var cost = 25
    @State private var icon = "gift.fill"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                Stepper("Cost: \(cost) ⭐", value: $cost, in: 5...500, step: 5)
                Text("Reward claims are always sent to a parent for approval before points are spent.")
                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            }
            .navigationTitle("New reward")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try appState.store.addReward(
                                name: name,
                                description: description,
                                icon: icon,
                                pointCost: cost,
                                eligibleChildIds: []
                            )
                            dismiss()
                        } catch {
                            appState.presentError(error)
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct FamilyView: View {
    @Environment(AppState.self) private var appState
    @State private var showChildEditor = false
    @State private var familyName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Family") {
                    TextField("Family name", text: $familyName)
                        .onAppear { familyName = appState.currentFamily?.name ?? "" }
                        .onSubmit { try? appState.store.updateFamilyName(familyName) }
                }
                Section("Kids") {
                    ForEach(appState.familyChildren) { child in
                        HStack {
                            ChildAvatarView(avatar: child.avatar, size: 40)
                            VStack(alignment: .leading) {
                                Text(child.name)
                                Text("\(child.activePoints) ⭐")
                                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                            }
                        }
                    }
                    Button("Add child") { showChildEditor = true }
                }
                Section("Chore approvals") {
                    Toggle("Require parent approval by default", isOn: Binding(
                        get: { appState.currentFamily?.settings.requireApprovalByDefault ?? true },
                        set: { isRequired in
                            do {
                                try appState.store.updateRequireApprovalByDefault(isRequired)
                            } catch {
                                appState.presentError(error)
                            }
                        }
                    ))
                    Text("Individual chores can override this default.")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
                Section("This device") {
                    Picker("Interface", selection: Binding(
                        get: { appState.interfaceOverride },
                        set: { appState.interfaceOverride = $0 }
                    )) {
                        ForEach(AppState.InterfaceOverride.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        appState.signOut()
                    }
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showChildEditor) { ChildEditorView() }
        }
    }
}

struct ChildEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var avatar = ChildAvatar.default

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Section("Avatar") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))]) {
                        ForEach(Array(ChildAvatar.presets.enumerated()), id: \.offset) { _, preset in
                            Button {
                                avatar = preset
                            } label: {
                                ChildAvatarView(avatar: preset, size: 56)
                                    .overlay {
                                        if avatar == preset {
                                            Circle().stroke(KiddotasksDesignTokens.Colors.primary, lineWidth: 3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("New child")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try appState.store.addChild(name: name, avatar: avatar, dateOfBirth: nil)
                            dismiss()
                        } catch {
                            appState.presentError(error)
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct ActivityView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List(appState.store.transactions) { tx in
                HStack {
                    Image(systemName: tx.type.icon)
                    VStack(alignment: .leading) {
                        Text(tx.description)
                        Text(tx.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(KiddotasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                    }
                    Spacer()
                    Text(tx.amount > 0 ? "+\(tx.amount)" : "\(tx.amount)")
                        .foregroundStyle(tx.amount > 0 ? KiddotasksDesignTokens.Colors.success : KiddotasksDesignTokens.Colors.error)
                }
            }
            .navigationTitle("History")
        }
    }
}
