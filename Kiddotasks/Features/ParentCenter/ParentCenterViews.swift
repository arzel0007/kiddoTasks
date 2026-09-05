import SwiftUI

struct ParentControlCenter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayDashboardView()
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
                        Text("No chores yet. Tap + to add one.")
                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                    }
                    ForEach(active) { task in
                        NavigationLink {
                            TaskEditorView(task: task)
                        } label: {
                            TaskRow(task: task)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                taskPendingDeletion = task
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                try? appState.store.archiveTask(task.id)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(KiddotasksDesignTokens.Colors.warning)
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
                                        try? appState.store.restoreTask(task.id)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(KiddotasksDesignTokens.Colors.success)
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
                        try? appState.store.deleteTask(task.id)
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
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                Text("\(task.pointValue) ⭐ · \(task.recurrence.type.displayName)")
                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            if isArchived {
                Text("Archived")
                    .font(KiddotasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textTertiary)
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
        case .useFamilyDefault: return KiddotasksDesignTokens.Colors.primary
        case .alwaysRequireApproval: return KiddotasksDesignTokens.Colors.warning
        case .autoApprove: return KiddotasksDesignTokens.Colors.success
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

    private let icons = [
        "checkmark.circle.fill", "bed.double.fill", "fork.knife", "trash.fill",
        "book.fill", "figure.run", "mouth.fill", "tshirt.fill", "pawprint.fill",
        "leaf.fill", "sparkles", "cart.fill", "pencil.and.outline", "gamecontroller.fill",
        "music.note", "hammer.fill", "heart.fill"
    ]

    /// Maps common chore keywords to a matching SF Symbol name.
    private static func suggestedIcon(for name: String) -> String {
        let lower = name.lowercased()
        let mapping: [(keywords: [String], icon: String)] = [
            (["bed", "sleep", "tidy room", "make bed"], "bed.double.fill"),
            (["dish", "kitchen", "plate", "food", "cook", "meal", "set table", "clear table"], "fork.knife"),
            (["trash", "garbage", "take out", "bin"], "trash.fill"),
            (["read", "book", "study", "homework", "school"], "book.fill"),
            (["run", "exercise", "play outside", "sport", "walk", "bike"], "figure.run"),
            (["teeth", "brush", "shower", "bath", "wash", "clean body"], "mouth.fill"),
            (["laundry", "clothes", "fold", "dress"], "tshirt.fill"),
            (["pet", "dog", "cat", "feed animal", "walk dog"], "pawprint.fill"),
            (["garden", "plant", "water", "weed", "mow"], "leaf.fill"),
            (["vacuum", "sweep", "mop", "dust", "clean", "tidy"], "sparkles"),
            (["shop", "grocery", "buy", "store"], "cart.fill"),
            (["write", "draw", "art", "craft"], "pencil.and.outline"),
            (["practice", "piano", "instrument", "music"], "music.note"),
            (["fix", "repair", "build", "tool"], "hammer.fill"),
            (["love", "help", "care", "kind", "share"], "heart.fill")
        ]
        for (keywords, icon) in mapping {
            for keyword in keywords {
                if lower.contains(keyword) {
                    return icon
                }
            }
        }
        return "checkmark.circle.fill"
    }

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
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                        ForEach(icons, id: \.self) { item in
                            Button {
                                icon = item
                                didPickIconManually = true
                            } label: {
                                Image(systemName: item)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(icon == item ? .white : KiddotasksDesignTokens.Colors.textSecondary)
                                    .frame(width: 48, height: 48)
                                    .background {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(icon == item ? KiddotasksDesignTokens.Colors.primary : KiddotasksDesignTokens.Colors.surface)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(icon == item ? Color.clear : KiddotasksDesignTokens.Colors.border, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
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
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .onAppear(perform: loadTaskIfEditing)
            .onChange(of: name) { _, newValue in
                if !didPickIconManually {
                    icon = TaskEditorView.suggestedIcon(for: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.isEmpty)
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
                        Text("No rewards yet. Tap + to add one.")
                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
                                            .fill(KiddotasksDesignTokens.Colors.accent)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(reward.name)
                                        .font(KiddotasksDesignTokens.Typography.titleSmall)
                                    Text("\(reward.pointCost) ⭐")
                                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                reward.isActive = false
                                try? appState.store.updateReward(reward)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(KiddotasksDesignTokens.Colors.warning)
                        }
                    }
                }

                let archived = appState.store.rewards.filter { !$0.isActive }
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { reward in
                            HStack {
                                Text(reward.name)
                                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                                Spacer()
                                Text("Archived")
                                    .font(KiddotasksDesignTokens.Typography.captionSmall)
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.textTertiary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    reward.isActive = true
                                    try? appState.store.updateReward(reward)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(KiddotasksDesignTokens.Colors.success)
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
            .navigationTitle(reward == nil ? "New reward" : "Edit reward")
            .onAppear(perform: loadRewardIfEditing)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.isEmpty)
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showFamilyNameEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            KiddotasksLogoMark(size: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(appState.currentFamily?.name ?? "Our family")
                                    .font(KiddotasksDesignTokens.Typography.titleMedium)
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                                Text("Kiddotasks family · tap to rename")
                                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
                        }
                    }
                }

                Section("Family code") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share this code with other parents")
                                .font(KiddotasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                            Text(appState.currentFamily?.familyCode ?? "------")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
                        }
                        Spacer()
                        Button {
                            if let code = appState.currentFamily?.familyCode {
                                UIPasteboard.general.string = code
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
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
                                    ChildAvatarView(avatar: child.avatar, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(child.name)
                                            .font(KiddotasksDesignTokens.Typography.titleSmall)
                                        Text("\(child.activePoints) ⭐ balance")
                                            .font(KiddotasksDesignTokens.Typography.captionLarge)
                                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                                    }
                                }
                            }
                            Button {
                                pointsEditorChild = child
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(KiddotasksDesignTokens.Colors.primary.opacity(0.10)))
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
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
                Section {
                    Button("Reset all data", role: .destructive) {
                        showResetConfirm = true
                    }
                    .foregroundStyle(KiddotasksDesignTokens.Colors.error)
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
                        try? appState.store.removeChild(child.id)
                    }
                    childPendingRemoval = nil
                }
                Button("Cancel", role: .cancel) { childPendingRemoval = nil }
            } message: {
                Text("Their history and earned stars stay in the family record.")
            }
            .alert("Reset all data?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    appState.store.resetAllData()
                    appState.signOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your family, kids, tasks, rewards, and all history. This cannot be undone.")
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
            Form {
                TextField("Family name", text: $name)
            }
            .navigationTitle("Family name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? appState.store.updateFamilyName(name)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
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
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("4–6 digits", text: $pin)
                    .keyboardType(.numberPad)
                Button("Save") {
                    do {
                        try appState.store.updateKidsPIN(pin)
                        pin = ""
                        statusMessage = "PIN updated ✓"
                    } catch {
                        statusMessage = error.localizedDescription
                    }
                }
                .disabled(pin.count < 4)
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var didLoad = false

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
                Section("Birthday (optional)") {
                    Toggle("Add birthday", isOn: $hasBirthday.animation())
                    if hasBirthday {
                        DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(child == nil ? "New child" : "Edit child")
            .onAppear(perform: loadChildIfEditing)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func loadChildIfEditing() {
        guard !didLoad, let child else { return }
        didLoad = true
        name = child.name
        avatar = child.avatar
        if let dateOfBirth = child.dateOfBirth {
            hasBirthday = true
            birthday = dateOfBirth
        }
    }

    private func save() {
        do {
            if let existing = child {
                existing.name = name
                existing.avatar = avatar
                existing.dateOfBirth = hasBirthday ? birthday : nil
                try appState.store.updateChild(existing)
            } else {
                try appState.store.addChild(
                    name: name,
                    avatar: avatar,
                    dateOfBirth: hasBirthday ? birthday : nil
                )
            }
            dismiss()
        } catch {
            appState.presentError(error)
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
                    Text("No activity yet. Completions and rewards will appear here.")
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
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
                                        ? KiddotasksDesignTokens.Colors.success
                                        : KiddotasksDesignTokens.Colors.error
                                )
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description)
                                .font(KiddotasksDesignTokens.Typography.bodyMedium)
                            Text(tx.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(KiddotasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                        }
                        Spacer()
                        Text(tx.amount > 0 ? "+\(tx.amount)" : "\(tx.amount)")
                            .font(KiddotasksDesignTokens.Typography.titleSmall)
                            .monospacedDigit()
                            .foregroundStyle(
                                tx.amount > 0
                                    ? KiddotasksDesignTokens.Colors.success
                                    : KiddotasksDesignTokens.Colors.error
                            )
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("History")
        }
    }
}
