import SwiftUI

// MARK: - Shared wishlist helpers

/// Solid status tag — compact, smaller than item titles.
struct WishlistStatusChip: View {
    let status: WishlistStatus

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(fillColor))
            .accessibilityLabel("Status: \(status.displayName)")
    }

    private var fillColor: Color {
        switch status {
        case .pending:
            return KiddoTasksDesignTokens.Colors.primary
        case .approved:
            return KiddoTasksDesignTokens.Colors.success
        case .rejected:
            return KiddoTasksDesignTokens.Colors.error
        case .received:
            return KiddoTasksDesignTokens.Colors.textSecondary
        }
    }
}

/// Cloud-or-local orchestration for wishlist mutations.
/// Local store always reflects UI state; cloud callables keep multi-device and
/// kids-session (no parent Auth) in sync. Review never touches points.
@MainActor
enum WishlistMutationBridge {
    static func familyId(_ appState: AppState) -> String? {
        appState.store.family?.id
    }

    static func addChild(
        appState: AppState,
        childId: String,
        title: String,
        message: String,
        occasion: WishlistOccasion?
    ) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if appState.isCloudEnabled, let familyId = familyId(appState) {
            do {
                let remote = try await appState.cloudSync.addWishlistItem(
                    familyId: familyId,
                    childId: childId,
                    title: trimmedTitle,
                    message: trimmedMessage,
                    occasion: occasion?.rawValue
                )
                try appState.store.addWishlistItem(
                    id: remote.id,
                    childId: childId,
                    title: trimmedTitle,
                    message: trimmedMessage,
                    occasion: occasion
                )
                return
            } catch {
                // Offline / cloud failure → keep local so the child still sees the wish.
                try appState.store.addWishlistItem(
                    childId: childId,
                    title: trimmedTitle,
                    message: trimmedMessage,
                    occasion: occasion
                )
                return
            }
        }
        try appState.store.addWishlistItem(
            childId: childId,
            title: trimmedTitle,
            message: trimmedMessage,
            occasion: occasion
        )
    }

    static func updateItem(
        appState: AppState,
        item: WishlistItem,
        title: String,
        message: String,
        occasion: WishlistOccasion?
    ) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if appState.isCloudEnabled, let familyId = familyId(appState) {
            do {
                try await appState.cloudSync.updateWishlistItem(
                    familyId: familyId,
                    itemId: item.id,
                    title: trimmedTitle,
                    message: trimmedMessage,
                    occasion: occasion?.rawValue,
                    version: item.version
                )
            } catch {
                // Fall through to local update so offline edits still work.
            }
        }
        try appState.store.updateWishlistItem(
            item.id,
            title: trimmedTitle,
            message: trimmedMessage,
            occasion: occasion
        )
    }

    static func deleteItem(
        appState: AppState,
        item: WishlistItem
    ) async throws {
        if appState.isCloudEnabled, let familyId = familyId(appState) {
            do {
                try await appState.cloudSync.deleteWishlistItem(
                    familyId: familyId,
                    itemId: item.id,
                    childId: item.childId
                )
            } catch {
                // Local tombstone still propagates via snapshot push when parent Auth exists.
            }
        }
        try appState.store.deleteWishlistItem(item.id)
    }

    /// Approve/reject only — NEVER awards or deducts points.
    static func reviewItem(
        appState: AppState,
        item: WishlistItem,
        decision: WishlistStatus,
        parentResponse: String?
    ) async throws {
        if appState.isCloudEnabled, let familyId = familyId(appState) {
            do {
                _ = try await appState.cloudSync.reviewWishlistItem(
                    familyId: familyId,
                    itemId: item.id,
                    decision: decision.rawValue,
                    parentResponse: parentResponse,
                    version: item.version
                )
            } catch {
                // Keep local review so parent still sees the decision offline.
            }
        }
        try appState.store.reviewWishlistItem(
            item.id,
            decision: decision,
            parentResponse: parentResponse,
            reviewedBy: appState.store.parent?.id
        )
    }
}

// MARK: - Parent wishlist

/// Parent-facing wishlist inbox: child filter + pending approve/reject.
struct ParentWishlistView: View {
    @Environment(AppState.self) private var appState
    @State private var childFilter: String? = nil
    @State private var reviewTarget: WishlistItem?
    @State private var reviewDecision: WishlistStatus = .approved
    @State private var responseText = ""
    @State private var itemPendingDeletion: WishlistItem?

    private var wishlistEnabled: Bool {
        appState.currentFamily?.settings.enableWishlist ?? false
    }

    private var filteredItems: [WishlistItem] {
        let items = appState.store.wishlistItems(forChild: childFilter)
        return items.sorted { lhs, rhs in
            if lhs.isPending != rhs.isPending { return lhs.isPending }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var pendingItems: [WishlistItem] {
        filteredItems.filter(\.isPending)
    }

    private var otherItems: [WishlistItem] {
        filteredItems.filter { !$0.isPending }
    }

    private func childName(_ id: String) -> String {
        appState.store.children.first(where: { $0.id == id })?.name ?? "Child"
    }

    private func childOf(_ id: String) -> Child? {
        appState.store.children.first(where: { $0.id == id })
    }

    @ViewBuilder
    private func childAvatar(for childId: String, size: CGFloat) -> some View {
        if let child = childOf(childId) {
            ChildAvatarView(
                avatar: child.avatar,
                size: size,
                photoData: child.photoData,
                photoURL: child.photoURL
            )
        } else {
            Text("🎁")
                .font(.system(size: size * 0.5))
                .frame(width: size, height: size)
                .background(Circle().fill(KiddoTasksDesignTokens.Colors.accent.opacity(0.18)))
        }
    }

    private var pendingByChild: [String: Int] {
        var map: [String: Int] = [:]
        for item in appState.store.wishlistItems where item.isPending {
            map[item.childId, default: 0] += 1
        }
        return map
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ArzPageHeader(title: "Wishlist")

                if !wishlistEnabled {
                    EmptyStateView(
                        emoji: "🔒",
                        title: "Wishlist is off",
                        message: "Turn on Wishlist in Family settings so kids can add gift wishes. Approvals never change stars."
                    )
                } else {
                    List {
                        Section {
                            HStack(spacing: 8) {
                                Text("\(pendingItems.count) pending")
                                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                    .fontWeight(.bold)
                                if !otherItems.isEmpty {
                                    Text("· \(otherItems.count) reviewed")
                                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                }
                            }
                            Picker("Child", selection: Binding(
                                get: { childFilter ?? "all" },
                                set: { childFilter = ($0 == "all") ? nil : $0 }
                            )) {
                                Text(pendingItems.isEmpty ? "All kids" : "All kids (\(appState.store.wishlistItems.filter(\.isPending).count))")
                                    .tag("all")
                                ForEach(appState.store.children) { child in
                                    let count = pendingByChild[child.id] ?? 0
                                    Text(count > 0 ? "\(child.name) (\(count))" : child.name)
                                        .tag(child.id)
                                }
                            }
                        }

                        Section("Pending (\(pendingItems.count))") {
                            if pendingItems.isEmpty {
                                EmptyListHint(
                                    emoji: "🌟",
                                    title: "No wishes waiting.",
                                    actionTitle: "Open Kids Station",
                                    action: { appState.interfaceOverride = .kids }
                                )
                            }
                            ForEach(pendingItems) { item in
                                wishlistRow(item, showStatusTag: false)
                            }
                        }

                        if !otherItems.isEmpty {
                            Section("Reviewed (\(otherItems.count))") {
                                ForEach(otherItems) { item in
                                    wishlistRow(item, showStatusTag: true)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(KiddoTasksDesignTokens.PageBackgrounds.parentPage.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $reviewTarget) { item in
                reviewSheet(item)
            }
            .confirmationDialog(
                "Delete “\(itemPendingDeletion?.title ?? "")”?",
                isPresented: Binding(
                    get: { itemPendingDeletion != nil },
                    set: { if !$0 { itemPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete wish", role: .destructive) {
                    if let item = itemPendingDeletion {
                        Task {
                            do {
                                try await WishlistMutationBridge.deleteItem(appState: appState, item: item)
                                appState.toastSuccess("Wish deleted")
                            } catch {
                                appState.toastError(error.localizedDescription)
                            }
                        }
                    }
                    itemPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { itemPendingDeletion = nil }
            } message: {
                Text("This only removes the wishlist item. Points are not affected.")
            }
        }
    }

    @ViewBuilder
    private func wishlistRow(_ item: WishlistItem, showStatusTag: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                childAvatar(for: item.childId, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    Text("\(childName(item.childId)) · \(item.occasion?.displayName ?? "Wish")")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    if !item.message.isEmpty {
                        Text(item.message)
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .lineLimit(3)
                    }
                    if item.hasParentResponse, let response = item.parentResponse {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("YOU REPLIED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                            Text(response)
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .italic()
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.primaryLight.opacity(0.45))
                        )
                    }
                }
                Spacer(minLength: 0)
                if showStatusTag {
                    WishlistStatusChip(status: item.status)
                }
            }

            if item.isPending {
                HStack(spacing: 10) {
                    Button {
                        reviewDecision = .approved
                        responseText = item.parentResponse ?? ""
                        reviewTarget = item
                    } label: {
                        Text("Approve")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(KiddoTasksDesignTokens.Colors.success)
                            )
                    }
                    .buttonStyle(KiddoPressStyle())
                    .accessibilityLabel("Approve \(item.title)")

                    Button {
                        reviewDecision = .rejected
                        responseText = item.parentResponse ?? ""
                        reviewTarget = item
                    } label: {
                        Text("Not now")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .fontWeight(.bold)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(KiddoTasksDesignTokens.Colors.error.opacity(0.12))
                            )
                    }
                    .buttonStyle(KiddoPressStyle())
                    .accessibilityLabel("Reject \(item.title)")
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                itemPendingDeletion = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(KiddoTasksDesignTokens.Colors.error)
        }
    }

    private func reviewSheet(_ item: WishlistItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    SectionCard(title: item.title, icon: "heart.text.square") {
                        Text("\(childName(item.childId)) · \(item.occasion?.displayName ?? "Wish")")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        if !item.message.isEmpty {
                            Text(item.message)
                                .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                        }
                    }

                    KiddoFormSection(title: "Decision", icon: reviewDecision.systemImage) {
                        Picker("Decision", selection: $reviewDecision) {
                            Text("Approve").tag(WishlistStatus.approved)
                            Text("Not now").tag(WishlistStatus.rejected)
                        }
                        .pickerStyle(.segmented)
                        KiddoTextField(
                            label: "Message to \(childName(item.childId))",
                            placeholder: "Optional note",
                            text: $responseText
                        )
                        Text("This does not change stars or reward points.")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }

                    PrimaryButton(title: reviewDecision == .approved ? "Approve wish" : "Send “not now”") {
                        let decision = reviewDecision
                        let response = responseText
                        Task {
                            do {
                                try await WishlistMutationBridge.reviewItem(
                                    appState: appState,
                                    item: item,
                                    decision: decision,
                                    parentResponse: response
                                )
                                appState.toastSuccess(
                                    decision == .approved ? "Wish approved" : "Marked not now"
                                )
                                reviewTarget = nil
                            } catch {
                                appState.toastError(error.localizedDescription)
                            }
                        }
                    }
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("Review wish")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { reviewTarget = nil }
                }
            }
        }
    }
}

// MARK: - Kids wishlist

/// Kids Station wishlist tab: list, add, edit/delete pending, show parent notes.
struct KidsWishlistView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    @State private var editTarget: WishlistItem?
    @State private var itemPendingDeletion: WishlistItem?

    private var child: Child? {
        guard let selected = appState.currentChildProfile else { return nil }
        return appState.child(id: selected.id)
    }

    private var wishlistEnabled: Bool {
        appState.currentFamily?.settings.enableWishlist ?? false
    }

    private func items(for child: Child) -> [WishlistItem] {
        appState.store.wishlistItems(forChild: child.id).sorted { lhs, rhs in
            if lhs.isPending != rhs.isPending { return lhs.isPending }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if child == nil {
                    EmptyStateView(
                        emoji: "🧒",
                        title: "Pick your face",
                        message: "Choose who is playing to see their wishlist."
                    )
                } else if !wishlistEnabled {
                    EmptyStateView(
                        emoji: "🔒",
                        title: "Wishes are off",
                        message: "Ask a parent to turn on Wishlist in Family settings. Wishes never use stars."
                    )
                } else if let child {
                    let list = items(for: child)
                    if list.isEmpty {
                        EmptyStateView(
                            emoji: "🎁",
                            title: "No wishes yet",
                            message: "Add something you’d love — a book, toy, or experience.",
                            actionTitle: "Add a wish",
                            action: { showAddSheet = true }
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                                    kidWishlistCard(item, child: child)
                                        .popIn(delay: Double(index) * 0.05)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .kiddoChildPageBackground(child, base: KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop)
            .safeAreaInset(edge: .top, spacing: 0) {
                ArzPageHeader(title: "My wishes") {
                    if wishlistEnabled, child != nil {
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(KiddoTasksDesignTokens.Colors.primary))
                        }
                        .buttonStyle(KiddoPressStyle())
                        .accessibilityLabel("Add a wish")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                if let child {
                    WishlistEditorSheet(childId: child.id, existing: nil)
                }
            }
            .sheet(item: $editTarget) { item in
                if let child {
                    WishlistEditorSheet(childId: child.id, existing: item)
                }
            }
            .confirmationDialog(
                "Remove “\(itemPendingDeletion?.title ?? "")”?",
                isPresented: Binding(
                    get: { itemPendingDeletion != nil },
                    set: { if !$0 { itemPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove wish", role: .destructive) {
                    if let item = itemPendingDeletion {
                        Task {
                            do {
                                try await WishlistMutationBridge.deleteItem(appState: appState, item: item)
                                appState.toastSuccess("Wish removed")
                            } catch {
                                appState.toastError(error.localizedDescription)
                            }
                        }
                    }
                    itemPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { itemPendingDeletion = nil }
            }
        }
    }

    @ViewBuilder
    private func kidWishlistCard(_ item: WishlistItem, child: Child) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ChildAvatarView(
                    avatar: child.avatar,
                    size: 52,
                    photoData: child.photoData,
                    photoURL: child.photoURL
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    Text(item.occasion?.displayName ?? "Wish")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    if !item.message.isEmpty {
                        Text(item.message)
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
                WishlistStatusChip(status: item.status)
            }

            if item.hasParentResponse, let response = item.parentResponse {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                    Text(response)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KiddoTasksDesignTokens.Colors.primary.opacity(0.08))
                )
            }

            HStack(spacing: 10) {
                if item.isEditableByChild {
                    Button {
                        editTarget = item
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(KiddoTasksDesignTokens.Colors.primary.opacity(0.12)))
                    }
                    .buttonStyle(KiddoPressStyle())
                }
                if item.isDeletableByChild {
                    Button {
                        itemPendingDeletion = item
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(KiddoTasksDesignTokens.Colors.error.opacity(0.12)))
                    }
                    .buttonStyle(KiddoPressStyle())
                }
                Spacer(minLength: 0)
            }
        }
        .padding(KiddoTasksDesignTokens.Spacing.medium)
        .background(KiddoTasksDesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.extraLarge, style: .continuous))
        .kiddotasksShadow(.medium)
    }
}

/// Add / edit sheet for a single wishlist item (title, message — no occasion for kids).
struct WishlistEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let childId: String
    var existing: WishlistItem?

    @State private var title = ""
    @State private var message = ""
    @State private var didLoad = false
    @State private var isSaving = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    KiddoFormSection(title: "Your wish", icon: "heart") {
                        KiddoTextField(
                            label: "What do you wish for?",
                            placeholder: "e.g. Blue bicycle",
                            text: $title,
                            caption: "Up to 120 characters"
                        )
                        KiddoTextArea(
                            label: "Why do you want it?",
                            placeholder: "Tell your parents a little more…",
                            text: $message
                        )
                        Text("Wishes are not the same as reward shop items. Parents review wishes — stars are never spent.")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }

                    PrimaryButton(
                        title: existing == nil ? "Add wish" : "Save wish",
                        isDisabled: trimmedTitle.isEmpty || isSaving
                    ) {
                        save()
                    }
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop)
            .navigationTitle(existing == nil ? "New wish" : "Edit wish")
            .onAppear(perform: loadIfNeeded)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing else { return }
        title = existing.title
        message = existing.message
    }

    private func save() {
        guard !trimmedTitle.isEmpty, !isSaving else { return }
        isSaving = true
        let item = existing
        // Kids do not set occasion; preserve any existing value on edit.
        let occasionValue = existing?.occasion
        let messageValue = message
        Task {
            do {
                if let item {
                    try await WishlistMutationBridge.updateItem(
                        appState: appState,
                        item: item,
                        title: trimmedTitle,
                        message: messageValue,
                        occasion: occasionValue
                    )
                    appState.toastSuccess("Wish updated")
                } else {
                    try await WishlistMutationBridge.addChild(
                        appState: appState,
                        childId: childId,
                        title: trimmedTitle,
                        message: messageValue,
                        occasion: nil
                    )
                    appState.toastSuccess("Wish added")
                }
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    appState.toastError(error.localizedDescription)
                }
            }
        }
    }
}
