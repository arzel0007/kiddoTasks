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
    @State private var search = ""

    private var activeTasks: [KiddoTask] {
        let base = appState.store.tasks.filter(\.isActive)
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Active") {
                    let active = activeTasks
                    if active.isEmpty {
                        EmptyListHint(
                            emoji: "📋",
                            title: search.isEmpty
                                ? "No chores yet. Create one for the kids."
                                : "No chores match “\(search)”.",
                            actionTitle: search.isEmpty ? "Add task" : nil
                        ) {
                            showEditor = true
                        }
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
                                    appState.toastSuccessUndo("Task archived") {
                                        do {
                                            try appState.store.restoreTask(task.id)
                                            appState.toastSuccess("Task restored")
                                        } catch {
                                            appState.toastError(error.localizedDescription)
                                        }
                                    }
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
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chores")
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
                Section("Allowance & week bonus") {
                    let mode = appState.currentFamily?.settings.allowanceMode ?? .starsOnly
                    let daily = Int(appState.currentFamily?.settings.flatDailyAmount ?? 1)
                    Picker("Allowance", selection: Binding(
                        get: { mode },
                        set: { newMode in
                            try? appState.store.updateAllowanceMode(newMode, flatDailyAmount: Double(daily))
                        }
                    )) {
                        Text("Stars only").tag(AllowanceMode.starsOnly)
                        Text("Flat daily").tag(AllowanceMode.flatDaily)
                        Text("Per chore").tag(AllowanceMode.perChore)
                    }
                    if mode == .flatDaily {
                        Stepper("Daily rate: \(daily)", value: Binding(
                            get: { daily },
                            set: { v in
                                try? appState.store.updateAllowanceMode(.flatDaily, flatDailyAmount: Double(v))
                            }
                        ), in: 1...50)
                    }
                    KiddoTextField(
                        label: "Week bonus title",
                        placeholder: "Full week!",
                        text: Binding(
                            get: { appState.currentFamily?.settings.weekBonusTitle ?? "Full week!" },
                            set: { title in
                                try? appState.store.updateWeekBonusTitle(title)
                            }
                        )
                    )
                    Text("Stars stay in-app. Allowance modes help you know what to pay in cash.")
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
                    Toggle("Mini-games hub", isOn: Binding(
                        get: { appState.currentFamily?.settings.enableMiniGames ?? true },
                        set: { isEnabled in
                            do {
                                try appState.store.updateMiniGamesEnabled(isEnabled)
                                appState.toastSuccess(isEnabled ? "Games hub enabled" : "Games hub hidden")
                            } catch {
                                appState.toastError(error.localizedDescription)
                            }
                        }
                    ))
                    if appState.currentFamily?.settings.enableMiniGames ?? true {
                        Stepper(
                            appState.currentFamily?.settings.basketballMaxMinutes == 0
                                ? "Basketball time: default"
                                : "Basketball time: \(appState.currentFamily?.settings.basketballMaxMinutes ?? 0) min",
                            value: Binding(
                                get: { appState.currentFamily?.settings.basketballMaxMinutes ?? 0 },
                                set: { value in
                                    try? appState.store.updateBasketballMaxMinutes(value)
                                }
                            ),
                            in: 0...30,
                            step: 5
                        )
                        Text("0 uses the standard 60s solo / 45s per player turns.")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }
                    Text("Shows basketball, tic-tac-toe, rock-paper-scissors, and memory in Kids Space.")
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
                    guard let item = newValue else { return }
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else {
                        appState.toastError("Couldn’t read that photo. Try another image.")
                        return
                    }
                    guard let compressed = ImageCompressor.compress(uiImage) else {
                        appState.toastError("Couldn’t prepare the photo for upload.")
                        return
                    }
                    // Always save locally first.
                    try? appState.store.updateFamilyPhoto(compressed)
                    var photoURL: String? = appState.currentFamily?.photoURL
                    if appState.isCloudEnabled, let familyId = appState.currentFamily?.id {
                        do {
                            photoURL = try await FamilyPhotoStorage.uploadPhoto(
                                familyId: familyId,
                                kind: .family,
                                itemId: familyId,
                                data: compressed
                            )
                            try appState.store.updateFamilyPhoto(compressed, photoURL: photoURL)
                            appState.toastSuccess("Family photo updated")
                        } catch {
                            print("[Photo] family upload failed: \(error.localizedDescription)")
                            appState.toastError(error.localizedDescription)
                        }
                    } else {
                        appState.toastSuccess("Family photo updated")
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
                "Reset all data for “\(appState.currentFamily?.name ?? "this family")”?",
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
                Text("This permanently deletes tasks, rewards, points, and history from this device and the cloud. You cannot undo this.")
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
                        // Keep cloud kidsPins index in sync when possible.
                        if appState.isCloudEnabled {
                            Task { @MainActor in
                                try? await appState.cloudSync.syncKidsPINIndex(pin: pin)
                            }
                        }
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
                    guard let item = newValue else { return }
                    do {
                        let data = try await item.loadTransferable(type: Data.self)
                        guard let data, let uiImage = UIImage(data: data) else {
                            await MainActor.run {
                                appState.toastError("Couldn’t read that photo.")
                            }
                            return
                        }
                        await MainActor.run {
                            photoData = ImageCompressor.compress(uiImage)
                        }
                    } catch {
                        await MainActor.run {
                            appState.toastError("Couldn’t load photo: \(error.localizedDescription)")
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
                let familyId = appState.currentFamily?.id

                if let existing = child {
                    // Upload using the **existing** child id so the Storage path matches.
                    var photoURL = existing.photoURL
                    if let photoData, appState.isCloudEnabled, let familyId {
                        do {
                            photoURL = try await FamilyPhotoStorage.uploadPhoto(
                                familyId: familyId,
                                kind: .child,
                                itemId: existing.id,
                                data: photoData
                            )
                        } catch {
                            // Keep local photo; cloud can retry later / other device.
                            print("[Photo] child upload failed (local kept): \(error.localizedDescription)")
                            appState.toastError(error.localizedDescription)
                            photoURL = existing.photoURL
                        }
                    }
                    existing.name = name
                    existing.avatar = avatar
                    existing.photoData = photoData
                    if photoData == nil { existing.photoURL = nil }
                    else { existing.photoURL = photoURL }
                    existing.dateOfBirth = hasBirthday ? birthday : nil
                    try appState.store.updateChild(existing)
                } else {
                    // Create first so we have a stable id, then upload under that id.
                    let created = try appState.store.addChild(
                        name: name,
                        avatar: avatar,
                        photoData: photoData,
                        photoURL: nil,
                        dateOfBirth: hasBirthday ? birthday : nil
                    )
                    if let photoData, appState.isCloudEnabled, let familyId {
                        do {
                            let url = try await FamilyPhotoStorage.uploadPhoto(
                                familyId: familyId,
                                kind: .child,
                                itemId: created.id,
                                data: photoData
                            )
                            created.photoURL = url
                            try appState.store.updateChild(created)
                        } catch {
                            print("[Photo] child upload failed (local kept): \(error.localizedDescription)")
                            appState.toastError(error.localizedDescription)
                        }
                    }
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

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case games = "Games"
        case points = "Points"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all

    private func childName(_ id: String) -> String {
        appState.child(id: id)?.name ?? "Child"
    }

    private var gameIconName: String {
        "gamecontroller.fill"
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                let transactions = appState.store.transactions.sorted {
                    $0.createdAt > $1.createdAt
                }
                let games = GameStatsStore.shared.records
                let showGames = filter != .points
                let showPoints = filter != .games

                if showGames {
                    Section {
                        if games.isEmpty {
                            Text("No games yet — kids can play from Games in Kids Space.")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                        ForEach(games) { match in
                            GameHistoryRow(match: match)
                        }
                    } header: {
                        Text("Mini-games")
                    } footer: {
                        if !games.isEmpty {
                            Text("Shows players, scores, winner, and time for each finished match.")
                        }
                    }
                }

                if showPoints {
                    Section("Stars & rewards") {
                        if transactions.isEmpty && (!showGames || games.isEmpty) {
                            EmptyListHint(
                                emoji: "📖",
                                title: "No activity yet. Completions, rewards, and games will appear here."
                            )
                        } else if transactions.isEmpty {
                            Text("No point activity yet.")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                        ForEach(transactions) { tx in
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
                                    Text(childName(tx.childId))
                                        .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                                        .fontWeight(.semibold)
                                    Text(tx.description)
                                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                    Text("\(tx.type.displayName) · \(tx.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
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
                }
            }
            .navigationTitle("History")
        }
    }
}

/// One finished mini-game: who played, scores, winner, when.
private struct GameHistoryRow: View {
    @Environment(AppState.self) private var appState
    let match: GameMatchRecord

    private var accent: Color {
        Color(hex: MiniGameID(rawValue: match.gameId)?.accentHex ?? "#3978A8")
    }

    private var isTie: Bool {
        match.winnerNames.count > 1
    }

    private var winnerLabel: String? {
        guard !match.winnerNames.isEmpty else { return nil }
        if isTie { return "Tie" }
        return match.winnerNames[0]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: MiniGameID(rawValue: match.gameId)?.symbol ?? "gamecontroller.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background { Circle().fill(accent) }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(match.displayTitle)
                        .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                        .fontWeight(.semibold)
                    Spacer(minLength: 8)
                    if let winnerLabel {
                        Text(winnerLabel)
                            .font(KiddoTasksDesignTokens.Typography.captionSmall)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(KiddoTasksDesignTokens.Colors.successLight))
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.success)
                    }
                }

                // Avatars when players are linked kids, otherwise plain names.
                HStack(spacing: -6) {
                    ForEach(match.players.prefix(4)) { player in
                        if let childId = player.childId, let child = appState.child(id: childId) {
                            ChildAvatarView(
                                avatar: child.avatar,
                                size: 22,
                                photoData: child.photoData,
                                photoURL: child.photoURL
                            )
                            .overlay(Circle().strokeBorder(KiddoTasksDesignTokens.Colors.surfaceCard, lineWidth: 1.5))
                        } else {
                            Text(String(player.displayName.prefix(1)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: player.colorHex))
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color(hex: player.colorHex).opacity(0.2)))
                                .overlay(Circle().strokeBorder(KiddoTasksDesignTokens.Colors.surfaceCard, lineWidth: 1.5))
                        }
                    }
                    if match.players.count > 4 {
                        Text("+\(match.players.count - 4)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(KiddoTasksDesignTokens.Colors.surface))
                    }
                    Text(match.playerNames)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .padding(.leading, 10)
                }
                .padding(.top, 2)

                if !match.scoreLine.isEmpty {
                    Text(match.scoreLine)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                }

                HStack(spacing: 6) {
                    Text(match.playedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                    if !match.durationLine.isEmpty {
                        Text("·")
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                        Text(match.durationLine)
                            .font(KiddoTasksDesignTokens.Typography.captionSmall)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
