import SwiftUI
import PhotosUI

struct ParentControlCenter: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayDashboardView()
                .tabItem { Label("Today", systemImage: "checkmark.seal.fill") }
                .tag(0)
            TaskListView()
                .tabItem { Label("Tasks", systemImage: "list.bullet.clipboard") }
                .tag(1)
            RewardListView()
                .tabItem { Label("Rewards", systemImage: "gift") }
                .tag(2)
            FamilyView()
                .tabItem { Label("Family", systemImage: "house.fill") }
                .tag(3)
            ActivityView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(4)
        }
        .tint(KiddoTasksDesignTokens.Colors.primary)
        .onChange(of: selectedTab) { _, _ in
            Haptic.light()
        }
    }
}

struct TaskListView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditor = false
    @State private var taskPendingDeletion: KiddoTask?

    var body: some View {
        NavigationStack {
            List {
                Section("Active") {
                    let active = appState.store.tasks.filter(\.isActive)
                    if active.isEmpty {
                        EmptyListHint(
                            emoji: "📋",
                            title: "No chores yet. Create one for the kids.",
                            actionTitle: "Add task"
                        ) { showEditor = true }
                    }
                    ForEach(active) { task in
                        NavigationLink {
                            TaskEditorView(task: task)
                        } label: {
                            TaskRow(task: task)
                        }
                        .buttonStyle(CardPressStyle())
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                taskPendingDeletion = task
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                do {
                                    try appState.store.archiveTask(task.id)
                                    appState.toastSuccess("Task archived")
                                } catch {
                                    appState.toastError(error.localizedDescription)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(KiddoTasksDesignTokens.Colors.warning)
                        }
                    }
                }

                let archived = appState.store.tasks.filter { !$0.isActive }
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { task in
                            TaskRow(task: task, isArchived: true)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        taskPendingDeletion = task
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        do {
                                            try appState.store.restoreTask(task.id)
                                            appState.toastSuccess("Task restored")
                                        } catch {
                                            appState.toastError(error.localizedDescription)
                                        }
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(KiddoTasksDesignTokens.Colors.success)
                                }
                        }
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
            .confirmationDialog(
                "Delete “\(taskPendingDeletion?.name ?? "")”?",
                isPresented: Binding(
                    get: { taskPendingDeletion != nil },
                    set: { if !$0 { taskPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete task", role: .destructive) {
                    if let task = taskPendingDeletion {
                        do {
                            try appState.store.deleteTask(task.id)
                            appState.toastSuccess("Task deleted")
                        } catch {
                            appState.toastError(error.localizedDescription)
                        }
                    }
                    taskPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { taskPendingDeletion = nil }
            } message: {
                Text("Past completions and stars stay in History. This cannot be undone.")
            }
        }
    }
}

/// Row shown in the Tasks list, active or archived.
struct TaskRow: View {
    let task: KiddoTask
    var isArchived = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(task.category.palette.accent)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                Text("\(task.pointValue) ⭐ · \(task.recurrence.type.displayName)")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            if isArchived {
                Text("Archived")
                    .font(KiddoTasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
            } else {
                Image(systemName: approvalIcon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(approvalTint)
                    .accessibilityLabel(approvalLabel)
            }
        }
        .padding(.vertical, 2)
    }

    private var approvalIcon: String {
        switch task.approvalBehavior {
        case .useFamilyDefault: return "house.fill"
        case .alwaysRequireApproval: return "checkmark.seal.fill"
        case .autoApprove: return "bolt.fill"
        }
    }

    private var approvalLabel: String {
        switch task.approvalBehavior {
        case .useFamilyDefault: return "Uses family default approval"
        case .alwaysRequireApproval: return "Always requires approval"
        case .autoApprove: return "Auto-approved"
        }
    }

    private var approvalTint: Color {
        switch task.approvalBehavior {
        case .useFamilyDefault: return KiddoTasksDesignTokens.Colors.primary
        case .alwaysRequireApproval: return KiddoTasksDesignTokens.Colors.warning
        case .autoApprove: return KiddoTasksDesignTokens.Colors.success
        }
    }
}

struct TaskEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    /// Pass a task to edit it; pass nil (or nothing) to create a new one.
    var task: KiddoTask? = nil

    @State private var name = ""
    @State private var didLoad = false
    @State private var description = ""
    @State private var points = 10
    @State private var category = TaskCategory.household
    @State private var recurrence = RecurrenceType.daily
    @State private var approvalBehavior = TaskApprovalBehavior.useFamilyDefault
    @State private var assigned: Set<String> = []
    @State private var icon = "checkmark.circle.fill"
    @State private var didPickIconManually = false

    private var categoryOptions: [KiddoChipOption<TaskCategory>] {
        TaskCategory.allCases.map { KiddoChipOption(id: $0, title: $0.displayName) }
    }

    private var recurrenceOptions: [KiddoChipOption<RecurrenceType>] {
        RecurrenceType.allCases.map { KiddoChipOption(id: $0, title: $0.displayName) }
    }

    private var approvalOptions: [KiddoChipOption<TaskApprovalBehavior>] {
        TaskApprovalBehavior.allCases.map { KiddoChipOption(id: $0, title: $0.displayName) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    KiddoFormSection(title: "Details", icon: "text.alignleft") {
                        KiddoTextField(label: "Name", placeholder: "e.g. Make your bed", text: $name)
                        KiddoTextArea(label: "Description", placeholder: "Optional tip for the kids", text: $description)
                    }

                    KiddoFormSection(title: "Reward", icon: "star.fill") {
                        KiddoPointsStepper(label: "Stars earned", value: $points, range: 1...100)
                    }

                    KiddoFormSection(title: "Schedule & rules", icon: "calendar") {
                        KiddoChipPicker(label: "Category", options: categoryOptions, selection: $category)
                        KiddoChipPicker(label: "Repeat", options: recurrenceOptions, selection: $recurrence)
                        KiddoChipPicker(label: "Approval", options: approvalOptions, selection: $approvalBehavior)
                    }

                    KiddoFormSection(title: "Icon", icon: "square.grid.2x2") {
                        KiddoIconPicker(
                            categories: KiddoIconCatalog.taskCategories,
                            selection: $icon,
                            onPick: { didPickIconManually = true }
                        )
                    }

                    if !appState.familyChildren.isEmpty {
                        KiddoFormSection(title: "Assign to", icon: "person.2.fill") {
                            FlowLayout(spacing: 8) {
                                ForEach(appState.familyChildren) { child in
                                    Button {
                                        Haptic.light()
                                        if assigned.contains(child.id) {
                                            assigned.remove(child.id)
                                        } else {
                                            assigned.insert(child.id)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            ChildAvatarView(avatar: child.avatar, size: 28, photoData: child.photoData)
                                            Text(child.name)
                                                .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                                                .fontWeight(.semibold)
                                            if assigned.contains(child.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.success)
                                            }
                                        }
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(
                                                assigned.contains(child.id)
                                                    ? KiddoTasksDesignTokens.Colors.success.opacity(0.15)
                                                    : KiddoTasksDesignTokens.Colors.surfaceElevated
                                            )
                                        )
                                        .overlay(
                                            Capsule().strokeBorder(
                                                assigned.contains(child.id)
                                                    ? KiddoTasksDesignTokens.Colors.success.opacity(0.4)
                                                    : KiddoTasksDesignTokens.Colors.borderSubtle,
                                                lineWidth: 1
                                            )
                                        )
                                    }
                                    .buttonStyle(KiddoPressStyle())
                                }
                            }
                        }
                    }
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .onAppear(perform: loadTaskIfEditing)
            .onChange(of: name) { _, newValue in
                if !didPickIconManually {
                    icon = KiddoIconCatalog.suggestedTaskIcon(for: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func loadTaskIfEditing() {
        guard !didLoad, let task else { return }
        didLoad = true
        name = task.name
        description = task.description
        points = task.pointValue
        category = task.category
        recurrence = task.recurrence.type
        approvalBehavior = task.approvalBehavior
        assigned = Set(task.assignedChildIds)
        icon = task.icon
    }

    private func save() {
        do {
            if let existing = task {
                existing.name = name
                existing.description = description
                existing.icon = icon
                existing.category = category
                existing.pointValue = points
                existing.approvalBehavior = approvalBehavior
                existing.assignedChildIds = Array(assigned)
                existing.recurrence = TaskRecurrence(type: recurrence, weekdays: existing.recurrence.weekdays)
                try appState.store.updateTask(existing)
            } else {
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
            }
            appState.toastSuccess(task == nil ? "Task created" : "Task updated")
            dismiss()
        } catch {
            appState.presentError(error)
        }
    }
}

struct RewardListView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section("Active") {
                    let active = appState.store.rewards.filter(\.isActive)
                    if active.isEmpty {
                        EmptyListHint(
                            emoji: "🎁",
                            title: "No rewards yet. Kids can shop once you add some.",
                            actionTitle: "Add reward"
                        ) { showEditor = true }
                    }
                    ForEach(active) { reward in
                        NavigationLink {
                            RewardEditorView(reward: reward)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: reward.icon)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(KiddoTasksDesignTokens.Colors.accent)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(reward.name)
                                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                    Text("\(reward.pointCost) ⭐")
                                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                reward.isActive = false
                                do {
                                    try appState.store.updateReward(reward)
                                    appState.toastSuccess("Reward archived")
                                } catch {
                                    appState.toastError(error.localizedDescription)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(KiddoTasksDesignTokens.Colors.warning)
                        }
                    }
                }

                let archived = appState.store.rewards.filter { !$0.isActive }
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { reward in
                            HStack {
                                Text(reward.name)
                                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                Spacer()
                                Text("Archived")
                                    .font(KiddoTasksDesignTokens.Typography.captionSmall)
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    reward.isActive = true
                                    do {
                                        try appState.store.updateReward(reward)
                                        appState.toastSuccess("Reward restored")
                                    } catch {
                                        appState.toastError(error.localizedDescription)
                                    }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(KiddoTasksDesignTokens.Colors.success)
                            }
                        }
                    }
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
    /// Pass a reward to edit it; pass nil (or nothing) to create a new one.
    var reward: Reward? = nil

    @State private var name = ""
    @State private var description = ""
    @State private var cost = 25
    @State private var icon = "gift.fill"
    @State private var didLoad = false
    @State private var didPickIconManually = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    KiddoFormSection(title: "Details", icon: "gift") {
                        KiddoTextField(label: "Name", placeholder: "e.g. Extra screen time", text: $name)
                        KiddoTextArea(label: "Description", placeholder: "What do they get?", text: $description)
                    }

                    KiddoFormSection(title: "Cost", icon: "star.fill") {
                        KiddoPointsStepper(label: "Stars needed", value: $cost, range: 5...500, step: 5)
                        Text("Reward claims always go to a parent for approval before points are spent.")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }

                    KiddoFormSection(title: "Icon", icon: "square.grid.2x2") {
                        KiddoIconPicker(
                            categories: KiddoIconCatalog.rewardCategories,
                            selection: $icon,
                            onPick: { didPickIconManually = true }
                        )
                    }
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle(reward == nil ? "New reward" : "Edit reward")
            .onAppear(perform: loadRewardIfEditing)
            .onChange(of: name) { _, newValue in
                if !didPickIconManually {
                    icon = KiddoIconCatalog.suggestedRewardIcon(for: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func loadRewardIfEditing() {
        guard !didLoad, let reward else { return }
        didLoad = true
        name = reward.name
        description = reward.description
        cost = reward.pointCost
        icon = reward.icon
    }

    private func save() {
        do {
            if let existing = reward {
                existing.name = name
                existing.description = description
                existing.pointCost = cost
                existing.icon = icon
                try appState.store.updateReward(existing)
            } else {
                try appState.store.addReward(
                    name: name,
                    description: description,
                    icon: icon,
                    pointCost: cost,
                    eligibleChildIds: []
                )
            }
            appState.toastSuccess(reward == nil ? "Reward created" : "Reward updated")
            dismiss()
        } catch {
            appState.presentError(error)
        }
    }
}

struct FamilyView: View {
    @Environment(AppState.self) private var appState
    @State private var showChildEditor = false
    @State private var childPendingRemoval: Child?
    @State private var showFamilyNameEditor = false
    @State private var pointsEditorChild: Child?
    @State private var showResetConfirm = false
    @State private var showFamilyPhotoPicker = false
    @State private var pickedFamilyPhoto: PhotosPickerItem?

    /// Clears cloud data (if any), resets the local store, and either signs out
    /// (full reset) or stays signed in with retained kids.
    ///
    /// Cloud wipe must succeed before local reset when cloud is enabled —
    /// otherwise leftover Firestore docs resurrect on the next pull.
    private func performReset(retainKids: Bool) {
        Task {
            if appState.isCloudEnabled {
                do {
                    try await appState.cloudSync.deleteCloudData()
                } catch {
                    await MainActor.run {
                        appState.errorMessage =
                            "Could not delete cloud data (\(error.localizedDescription)). Nothing was reset. Check your connection and try again."
                    }
                    return
                }
            }
            await MainActor.run {
                appState.store.resetAllData(retainKids: retainKids)
                appState.store.clearSyncMeta()
                if !retainKids {
                    appState.signOut()
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Button {
                            showFamilyPhotoPicker = true
                        } label: {
                            Group {
                                if let photoData = appState.currentFamily?.photoData,
                                   let uiImage = KiddoImageCache.image(from: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    KiddoTasksLogoMark(size: 80)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        VStack(spacing: 2) {
                            Text(appState.currentFamily?.name ?? "Our family")
                                .font(KiddoTasksDesignTokens.Typography.titleMedium)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                            Button {
                                showFamilyNameEditor = true
                            } label: {
                                Text("Tap to rename")
                                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                            }
                        }
                        if appState.currentFamily?.photoData != nil {
                            Button(role: .destructive) {
                                do {
                                    try appState.store.updateFamilyPhoto(nil)
                                    appState.toastSuccess("Family photo removed")
                                } catch {
                                    appState.toastError(error.localizedDescription)
                                }
                            } label: {
                                Text("Remove photo")
                                    .font(.system(size: 13))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("Family code") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share this code with other parents")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            Text(appState.currentFamily?.familyCode ?? "------")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                        }
                        Spacer()
                        Button {
                            if let code = appState.currentFamily?.familyCode {
                                UIPasteboard.general.string = code
                                appState.toastSuccess("Family code copied")
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                        }
                        .accessibilityLabel("Copy family code")
                    }
                }

                Section("Kids") {
                    ForEach(appState.familyChildren) { child in
                        HStack(spacing: 12) {
                            NavigationLink {
                                ChildEditorView(child: child)
                            } label: {
                                HStack(spacing: 12) {
                                    ChildAvatarView(avatar: child.avatar, size: 40, photoData: child.photoData, photoURL: child.photoURL)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(child.name)
                                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                        Text("\(child.activePoints) ⭐ balance")
                                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                    }
                                }
                            }
                            Button {
                                pointsEditorChild = child
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(KiddoTasksDesignTokens.Colors.primary.opacity(0.10)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Manage \(child.name)'s points")
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                childPendingRemoval = child
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                    }
                    Button {
                        showChildEditor = true
                    } label: {
                        Label("Add child", systemImage: "plus.circle.fill")
                    }
                }
                Section("Kids PIN") {
                    PINEditorRow()
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
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
                Section("Notifications & fun") {
                    Toggle("Family notifications", isOn: Binding(
                        get: { appState.currentFamily?.settings.enableNotifications ?? true },
                        set: { isEnabled in
                            do {
                                try appState.store.updateNotificationsEnabled(isEnabled)
                            } catch {
                                appState.presentError(error)
                            }
                        }
                    ))
                    Toggle("Celebration animations", isOn: Binding(
                        get: { appState.currentFamily?.settings.celebrationAnimationsEnabled ?? true },
                        set: { isEnabled in
                            do {
                                try appState.store.updateCelebrationsEnabled(isEnabled)
                            } catch {
                                appState.presentError(error)
                            }
                        }
                    ))
                    Toggle("Basketball mini-game", isOn: Binding(
                        get: { appState.currentFamily?.settings.enableMiniGames ?? true },
                        set: { isEnabled in
                            do {
                                try appState.store.updateMiniGamesEnabled(isEnabled)
                                appState.toastSuccess(isEnabled ? "Play tab enabled" : "Play tab hidden")
                            } catch {
                                appState.toastError(error.localizedDescription)
                            }
                        }
                    ))
                    Text("Shows a Play tab in Kids Space for the basketball challenge.")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
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
                    ThemeAppearancePicker()
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        Haptic.warning()
                        appState.signOut()
                    }
                }
                Section {
                    Button("Reset all data", role: .destructive) {
                        showResetConfirm = true
                    }
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showChildEditor) { ChildEditorView() }
            .sheet(isPresented: $showFamilyNameEditor) {
                FamilyNameEditor(initialName: appState.currentFamily?.name ?? "")
            }
            .sheet(item: $pointsEditorChild) { child in
                KidPointsEditor(child: child)
            }
            .photosPicker(isPresented: $showFamilyPhotoPicker, selection: $pickedFamilyPhoto, matching: .images)
            .onChange(of: pickedFamilyPhoto) { _, newValue in
                Task { @MainActor in
                    guard let item = newValue,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    let compressed = ImageCompressor.compress(uiImage)
                    do {
                        var photoURL: String? = appState.currentFamily?.photoURL
                        if let compressed, appState.isCloudEnabled, let familyId = appState.currentFamily?.id {
                            photoURL = try await FamilyPhotoStorage.uploadPhoto(
                                familyId: familyId,
                                kind: .family,
                                itemId: familyId,
                                data: compressed
                            )
                        }
                        try appState.store.updateFamilyPhoto(compressed, photoURL: photoURL)
                        appState.toastSuccess("Family photo updated")
                    } catch {
                        appState.toastError(error.localizedDescription)
                    }
                }
            }
            .confirmationDialog(
                "Remove \(childPendingRemoval?.name ?? "this child")?",
                isPresented: Binding(
                    get: { childPendingRemoval != nil },
                    set: { if !$0 { childPendingRemoval = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove child", role: .destructive) {
                    if let child = childPendingRemoval {
                        do {
                            try appState.store.removeChild(child.id)
                            appState.toastSuccess("\(child.name) removed")
                        } catch {
                            appState.toastError(error.localizedDescription)
                        }
                    }
                    childPendingRemoval = nil
                }
                Button("Cancel", role: .cancel) { childPendingRemoval = nil }
            } message: {
                Text("Their history and earned stars stay in the family record.")
            }
            .confirmationDialog(
                "Reset all data?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    performReset(retainKids: false)
                }
                Button("Keep Kids", role: .destructive) {
                    performReset(retainKids: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This deletes tasks, rewards, points, and history. You can choose to keep your kids.")
            }
        }
    }
}

/// Sheet for renaming the family, with an explicit save.
struct FamilyNameEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let initialName: String
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    KiddoFormSection(title: "Name", icon: "house") {
                        KiddoTextField(label: "Family name", placeholder: "Our family", text: $name)
                    }
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("Family name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try appState.store.updateFamilyName(name)
                            appState.toastSuccess("Family name updated")
                        } catch {
                            appState.toastError(error.localizedDescription)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { name = initialName }
    }
}

/// Inline Kids PIN editor: digits only, validated by the store on save.
struct PINEditorRow: View {
    @Environment(AppState.self) private var appState
    @State private var pin = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                KiddoTextField(
                    label: "Kids Station PIN",
                    placeholder: "4–6 digits",
                    text: $pin,
                    caption: "Kids enter this once on the shared iPad.",
                    keyboard: .numberPad,
                    isSecure: true
                )
                Button("Save") {
                    do {
                        try appState.store.updateKidsPIN(pin)
                        pin = ""
                        appState.toastSuccess("PIN updated")
                    } catch {
                        appState.toastError(error.localizedDescription)
                    }
                }
                .fontWeight(.semibold)
                .disabled(pin.count < 4)
                .padding(.bottom, 2)
            }
        }
        .onChange(of: pin) { _, newValue in
            pin = String(newValue.prefix(6).filter(\.isNumber))
        }
    }
}

struct ChildEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    /// Pass a child to edit; pass nil (or nothing) to add a new one.
    var child: Child? = nil

    @State private var name = ""
    @State private var avatar = ChildAvatar.default
    @State private var photoData: Data?
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var didLoad = false
    @State private var showPhotoPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    KiddoFormSection(title: "Profile", icon: "person.fill") {
                        KiddoTextField(label: "Name", placeholder: "Child's name", text: $name)
                    }

                    KiddoFormSection(title: "Photo", icon: "photo") {
                        HStack(spacing: 12) {
                            ChildAvatarView(avatar: avatar, size: 64, photoData: photoData)
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    showPhotoPicker = true
                                } label: {
                                    Label("Choose photo", systemImage: "photo")
                                }
                                if photoData != nil {
                                    Button(role: .destructive) {
                                        photoData = nil
                                    } label: {
                                        Label("Remove photo", systemImage: "trash")
                                    }
                                    .font(.system(size: 13))
                                }
                            }
                        }
                    }

                    KiddoFormSection(title: "Avatar", icon: "face.smiling") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))]) {
                            ForEach(Array(ChildAvatar.presets.enumerated()), id: \.offset) { _, preset in
                                Button {
                                    avatar = preset
                                    Haptic.light()
                                } label: {
                                    ChildAvatarView(avatar: preset, size: 56)
                                        .overlay {
                                            if avatar == preset {
                                                Circle().stroke(KiddoTasksDesignTokens.Colors.primary, lineWidth: 3)
                                            }
                                        }
                                }
                                .buttonStyle(KiddoPressStyle())
                            }
                        }
                    }

                    KiddoFormSection(title: "Birthday", icon: "gift") {
                        Toggle("Add birthday", isOn: $hasBirthday.animation())
                        if hasBirthday {
                            DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle(child == nil ? "New child" : "Edit child")
            .onAppear(perform: loadChildIfEditing)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedPhoto, matching: .images)
            .onChange(of: pickedPhoto) { _, newValue in
                Task {
                    if let item = newValue,
                       let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            photoData = ImageCompressor.compress(uiImage)
                        }
                    }
                }
            }
        }
    }

    @State private var pickedPhoto: PhotosPickerItem?

    private func loadChildIfEditing() {
        guard !didLoad, let child else { return }
        didLoad = true
        name = child.name
        avatar = child.avatar
        photoData = child.photoData
        if let dateOfBirth = child.dateOfBirth {
            hasBirthday = true
            birthday = dateOfBirth
        }
    }

    private func save() {
        Task { @MainActor in
            do {
                var photoURL = child?.photoURL
                let familyId = appState.currentFamily?.id
                let itemId = child?.id ?? UUID().uuidString

                // Upload to Storage when cloud is on so snapshots stay small.
                if let photoData, appState.isCloudEnabled, let familyId {
                    photoURL = try await FamilyPhotoStorage.uploadPhoto(
                        familyId: familyId,
                        kind: .child,
                        itemId: itemId,
                        data: photoData
                    )
                }

                if let existing = child {
                    existing.name = name
                    existing.avatar = avatar
                    existing.photoData = photoData
                    existing.photoURL = photoURL
                    existing.dateOfBirth = hasBirthday ? birthday : nil
                    try appState.store.updateChild(existing)
                } else {
                    try appState.store.addChild(
                        name: name,
                        avatar: avatar,
                        photoData: photoData,
                        photoURL: photoURL,
                        dateOfBirth: hasBirthday ? birthday : nil
                    )
                }
                appState.toastSuccess(child == nil ? "\(name) added" : "Profile updated")
                dismiss()
            } catch {
                appState.toastError(error.localizedDescription)
                appState.presentError(error)
            }
        }
    }
}

struct ActivityView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                let transactions = appState.store.transactions
                if transactions.isEmpty {
                    EmptyListHint(
                        emoji: "📖",
                        title: "No activity yet. Completions and rewards will appear here."
                    )
                }
                ForEach(transactions.reversed()) { tx in
                    HStack(spacing: 12) {
                        Image(systemName: tx.type.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background {
                                Circle().fill(
                                    tx.amount >= 0
                                        ? KiddoTasksDesignTokens.Colors.success
                                        : KiddoTasksDesignTokens.Colors.error
                                )
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description)
                                .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            Text(tx.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                        Spacer()
                        Text(tx.amount > 0 ? "+\(tx.amount)" : "\(tx.amount)")
                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            .monospacedDigit()
                            .foregroundStyle(
                                tx.amount > 0
                                    ? KiddoTasksDesignTokens.Colors.success
                                    : KiddoTasksDesignTokens.Colors.error
                            )
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Theme appearance

struct ThemeAppearancePicker: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Picker("Appearance", selection: Binding(
            get: { theme.appearance },
            set: { theme.appearance = $0 }
        )) {
            ForEach(KiddoAppearance.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
    }
}
