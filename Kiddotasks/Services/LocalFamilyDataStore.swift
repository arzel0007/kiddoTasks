import Foundation
import Observation
import CryptoKit

/// Snapshot persisted to UserDefaults so the app works without Firebase.
struct FamilySnapshot: Codable {
    var family: Family
    var parent: Parent
    var passwordHash: String
    var children: [Child]
    var tasks: [KiddoTask]
    var completions: [TaskCompletion]
    var rewards: [Reward]
    var claims: [RewardClaim]
    var transactions: [PointTransaction]
    var achievements: [Achievement]
}

/// In-memory family database with local persistence.
/// All point awards and deductions go through these methods (same rules as Cloud Functions).
@Observable
final class LocalFamilyDataStore {
    private static let storageKey = "kiddotasks.family.snapshot.v1"
    private static let sessionKey = "kiddotasks.session.parentId"

    var family: Family?
    var parent: Parent?
    var children: [Child] = []
    var tasks: [KiddoTask] = []
    var completions: [TaskCompletion] = []
    var rewards: [Reward] = []
    var claims: [RewardClaim] = []
    var transactions: [PointTransaction] = []
    var achievements: [Achievement] = []
    var dataRevision: Int = 0

    var isAuthenticated: Bool { parent != nil }

    init() {
        restoreSession()
    }

    // MARK: - Auth

    func signUp(familyName: String, parentName: String, email: String, password: String) throws {
        if loadSnapshot() != nil {
            deleteAllLocalData()
        }
        let familyId = UUID().uuidString
        let parentId = UUID().uuidString
        let newFamily = Family(id: familyId, name: familyName, memberIds: [parentId])
        let newParent = Parent(
            id: parentId,
            email: email.lowercased(),
            displayName: parentName,
            familyId: familyId,
            role: .owner,
            lastSignInAt: Date()
        )
        family = newFamily
        parent = newParent
        seedStarterContent(familyId: familyId, parentId: parentId)
        persist(passwordHash: Self.hash(password))
        UserDefaults.standard.set(parentId, forKey: Self.sessionKey)
    }

    func signIn(email: String, password: String) throws {
        guard let snapshot = loadSnapshot() else {
            throw FirebaseError.invalidCredentials
        }
        guard snapshot.parent.email.lowercased() == email.lowercased(),
              snapshot.passwordHash == Self.hash(password) else {
            throw FirebaseError.invalidCredentials
        }
        apply(snapshot)
        parent?.lastSignInAt = Date()
        persist(passwordHash: snapshot.passwordHash)
        UserDefaults.standard.set(snapshot.parent.id, forKey: Self.sessionKey)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.sessionKey)
        family = nil
        parent = nil
        children = []
        tasks = []
        completions = []
        rewards = []
        claims = []
        transactions = []
        achievements = []
        restoreSnapshotWithoutSession()
    }

    func deleteAllLocalData() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        UserDefaults.standard.removeObject(forKey: Self.sessionKey)
        family = nil
        parent = nil
        children = []
        tasks = []
        completions = []
        rewards = []
        claims = []
        transactions = []
        achievements = []
    }

    var hasExistingAccount: Bool {
        loadSnapshot() != nil
    }

    // MARK: - Children

    @discardableResult
    func addChild(name: String, avatar: ChildAvatar, dateOfBirth: Date?) throws -> Child {
        guard let family, let parent else { throw FirebaseError.notAuthenticated }
        let child = Child(name: name, familyId: family.id, avatar: avatar, dateOfBirth: dateOfBirth)
        children.append(child)
        family.memberIds.append(child.id)
        family.updatedAt = Date()
        persistKeepingPassword()
        _ = parent
        return child
    }

    func updateChild(_ child: Child) throws {
        guard let index = children.firstIndex(where: { $0.id == child.id }) else {
            throw FirebaseError.invalidChild
        }
        children[index] = child
        persistKeepingPassword()
    }

    // MARK: - Tasks

    @discardableResult
    func addTask(
        name: String,
        description: String,
        icon: String,
        category: TaskCategory,
        pointValue: Int,
        approvalBehavior: TaskApprovalBehavior,
        assignedChildIds: [String],
        recurrence: TaskRecurrence
    ) throws -> KiddoTask {
        guard let family, let parent else { throw FirebaseError.notAuthenticated }
        let task = KiddoTask(
            familyId: family.id,
            name: name,
            description: description,
            icon: icon,
            category: category,
            pointValue: pointValue,
            approvalBehavior: approvalBehavior,
            assignedChildIds: assignedChildIds,
            recurrence: recurrence,
            createdBy: parent.id
        )
        tasks.append(task)
        persistKeepingPassword()
        return task
    }

    func updateTask(_ task: KiddoTask) throws {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            throw FirebaseError.invalidTask
        }
        task.version += 1
        task.updatedAt = Date()
        tasks[index] = task
        persistKeepingPassword()
    }

    func archiveTask(_ taskId: String) throws {
        guard let task = tasks.first(where: { $0.id == taskId }) else {
            throw FirebaseError.invalidTask
        }
        task.isActive = false
        task.updatedAt = Date()
        persistKeepingPassword()
    }

    // MARK: - Completions (kids submit, parents approve)

    @discardableResult
    func submitCompletion(taskId: String, childId: String) throws -> TaskCompletion {
        guard let family else { throw FirebaseError.invalidFamily }
        guard let task = tasks.first(where: { $0.id == taskId && $0.isActive }) else {
            throw FirebaseError.invalidTask
        }
        guard children.contains(where: { $0.id == childId }) else {
            throw FirebaseError.invalidChild
        }
        let requiresApproval = task.requiresParentApproval(using: family.settings)
        let status: CompletionStatus = requiresApproval ? .awaitingApproval : .approved
        var completion = TaskCompletion(
            familyId: family.id,
            taskId: taskId,
            childId: childId,
            status: status
        )
        if !requiresApproval {
            completion = awardPoints(for: completion, task: task, parentId: "system")
        }
        completions.append(completion)
        persistKeepingPassword()
        return completion
    }

    func approveCompletion(_ completionId: String) throws {
        guard let parent else { throw FirebaseError.notAuthenticated }
        guard let index = completions.firstIndex(where: { $0.id == completionId }) else {
            throw FirebaseError.documentNotFound
        }
        let completion = completions[index]
        guard completion.status == .awaitingApproval || completion.status == .completed else {
            throw FirebaseError.alreadyExists
        }
        guard let task = tasks.first(where: { $0.id == completion.taskId }) else {
            throw FirebaseError.invalidTask
        }
        completions[index] = awardPoints(for: completion, task: task, parentId: parent.id)
        persistKeepingPassword()
    }

    func rejectCompletion(_ completionId: String, reason: String) throws {
        guard parent != nil else { throw FirebaseError.notAuthenticated }
        guard let completion = completions.first(where: { $0.id == completionId }) else {
            throw FirebaseError.documentNotFound
        }
        completion.status = .rejected
        completion.notes = reason
        persistKeepingPassword()
    }

    // MARK: - Rewards

    @discardableResult
    func addReward(
        name: String,
        description: String,
        icon: String,
        pointCost: Int,
        eligibleChildIds: [String]
    ) throws -> Reward {
        guard let family, let parent else { throw FirebaseError.notAuthenticated }
        let reward = Reward(
            familyId: family.id,
            name: name,
            description: description,
            icon: icon,
            pointCost: pointCost,
            eligibleChildIds: eligibleChildIds,
            requiresApproval: true,
            createdBy: parent.id
        )
        rewards.append(reward)
        persistKeepingPassword()
        return reward
    }

    func updateReward(_ reward: Reward) throws {
        guard let index = rewards.firstIndex(where: { $0.id == reward.id }) else {
            throw FirebaseError.invalidReward
        }
        reward.version += 1
        reward.updatedAt = Date()
        rewards[index] = reward
        persistKeepingPassword()
    }

    @discardableResult
    func claimReward(rewardId: String, childId: String) throws -> RewardClaim {
        guard let family else { throw FirebaseError.invalidFamily }
        guard let reward = rewards.first(where: { $0.id == rewardId && $0.isActive }) else {
            throw FirebaseError.invalidReward
        }
        guard let child = children.first(where: { $0.id == childId }) else {
            throw FirebaseError.invalidChild
        }
        guard reward.isEligibleFor(childId) else { throw FirebaseError.permissionDenied }
        guard reward.canAfford(with: child.activePoints) else { throw FirebaseError.insufficientPoints }

        let claim = RewardClaim(familyId: family.id, rewardId: rewardId, childId: childId)
        claims.append(claim)
        persistKeepingPassword()
        return claim
    }

    func approveClaim(_ claimId: String) throws {
        guard let parent else { throw FirebaseError.notAuthenticated }
        guard let index = claims.firstIndex(where: { $0.id == claimId }) else {
            throw FirebaseError.documentNotFound
        }
        let claim = claims[index]
        guard claim.status == .claimed else { throw FirebaseError.alreadyExists }
        guard let reward = rewards.first(where: { $0.id == claim.rewardId }) else {
            throw FirebaseError.invalidReward
        }
        guard let child = children.first(where: { $0.id == claim.childId }) else {
            throw FirebaseError.invalidChild
        }
        claims[index] = deductPoints(for: claim, reward: reward, child: child, parentId: parent.id)
        persistKeepingPassword()
    }

    func rejectClaim(_ claimId: String, reason: String) throws {
        guard parent != nil else { throw FirebaseError.notAuthenticated }
        guard let claim = claims.first(where: { $0.id == claimId }) else {
            throw FirebaseError.documentNotFound
        }
        claim.status = .rejected
        claim.notes = reason
        persistKeepingPassword()
    }

    func markClaimRedeemed(_ claimId: String) throws {
        guard parent != nil else { throw FirebaseError.notAuthenticated }
        guard let claim = claims.first(where: { $0.id == claimId }) else {
            throw FirebaseError.documentNotFound
        }
        guard claim.status == .approved else { throw FirebaseError.operationFailed("Approve this reward first") }
        claim.status = .redeemed
        persistKeepingPassword()
    }

    func updateFamilyName(_ name: String) throws {
        guard let family else { throw FirebaseError.notAuthenticated }
        family.name = name
        family.updatedAt = Date()
        persistKeepingPassword()
    }

    func updateKidsPIN(_ pin: String) throws {
        guard let family else { throw FirebaseError.notAuthenticated }
        family.settings.kidsStationPIN = pin
        family.updatedAt = Date()
        persistKeepingPassword()
    }

    func updateRequireApprovalByDefault(_ isRequired: Bool) throws {
        guard let family else { throw FirebaseError.notAuthenticated }
        family.settings.requireApprovalByDefault = isRequired
        family.updatedAt = Date()
        persistKeepingPassword()
    }

    // MARK: - Queries

    func tasksForChild(_ childId: String, on date: Date = Date()) -> [KiddoTask] {
        tasks.filter { $0.isActive && $0.isAssignedTo(childId) && $0.isDue(on: date) }
    }

    func todaysCompletion(taskId: String, childId: String) -> TaskCompletion? {
        completions.last {
            $0.taskId == taskId
            && $0.childId == childId
            && Calendar.current.isDateInToday($0.completedAt)
        }
    }

    func pendingCompletions() -> [TaskCompletion] {
        completions.filter { $0.status == .awaitingApproval || $0.status == .completed }
    }

    func pendingClaims() -> [RewardClaim] {
        claims.filter { $0.status == .claimed }
    }

    // MARK: - Private

    private func awardPoints(for completion: TaskCompletion, task: KiddoTask, parentId: String) -> TaskCompletion {
        guard let child = children.first(where: { $0.id == completion.childId }) else {
            return completion
        }
        if transactions.contains(where: {
            $0.relatedId == completion.id && $0.type == .taskCompletion && !$0.isReversed
        }) {
            return completion
        }
        let tx = PointTransaction(
            familyId: completion.familyId,
            childId: child.id,
            amount: task.pointValue,
            type: .taskCompletion,
            relatedId: completion.id,
            description: "Completed: \(task.name)",
            createdBy: parentId
        )
        transactions.append(tx)
        child.activePoints += task.pointValue
        child.totalPointsEarned += task.pointValue
        child.updatedAt = Date()
        completion.status = .approved
        completion.approvedAt = Date()
        completion.approvedBy = parentId
        completion.pointsAwarded = task.pointValue
        completion.pointTransactionId = tx.id
        awardAchievements(for: child)
        return completion
    }

    private func deductPoints(for claim: RewardClaim, reward: Reward, child: Child, parentId: String) -> RewardClaim {
        if child.activePoints < reward.pointCost {
            return claim
        }
        let tx = PointTransaction(
            familyId: claim.familyId,
            childId: child.id,
            amount: -reward.pointCost,
            type: .rewardRedemption,
            relatedId: claim.id,
            description: "Reward: \(reward.name)",
            createdBy: parentId
        )
        transactions.append(tx)
        child.activePoints -= reward.pointCost
        child.updatedAt = Date()
        claim.status = .approved
        claim.approvedAt = Date()
        claim.approvedBy = parentId
        claim.pointDeductionTransactionId = tx.id
        return claim
    }

    private func awardAchievements(for child: Child) {
        let existing = Set(achievements.filter { $0.childId == child.id }.map(\.type))
        func earn(_ type: AchievementType) {
            guard !existing.contains(type) else { return }
            achievements.append(Achievement(familyId: child.familyId, childId: child.id, type: type))
        }
        let approvedCount = completions.filter { $0.childId == child.id && $0.status == .approved }.count
        if approvedCount >= 1 { earn(.firstTask) }
        if child.totalPointsEarned >= 100 { earn(.points100) }
        if child.totalPointsEarned >= 250 { earn(.points250) }
        if child.totalPointsEarned >= 500 { earn(.points500) }
        let householdDone = completions.filter { completion in
            completion.childId == child.id
                && completion.status == .approved
                && tasks.first(where: { $0.id == completion.taskId })?.category == .household
        }.count
        if householdDone >= 10 { earn(.cleaningHero) }
    }

    private func seedStarterContent(familyId: String, parentId: String) {
        let childA = Child(name: "Alex", familyId: familyId, avatar: ChildAvatar.presets[1])
        let childB = Child(name: "Sam", familyId: familyId, avatar: ChildAvatar.presets[0])
        children = [childA, childB]
        family?.memberIds.append(contentsOf: [childA.id, childB.id])

        tasks = [
            KiddoTask(
                familyId: familyId,
                name: "Make your bed",
                description: "Pull up the sheets and put the pillows in place.",
                icon: "bed.double.fill",
                category: .household,
                pointValue: 10,
                requiresApproval: true,
                assignedChildIds: [childA.id, childB.id],
                recurrence: .daily,
                createdBy: parentId
            ),
            KiddoTask(
                familyId: familyId,
                name: "Brush teeth",
                description: "Two minutes, morning or night.",
                icon: "mouth.fill",
                category: .health,
                pointValue: 5,
                requiresApproval: false,
                assignedChildIds: [childA.id, childB.id],
                recurrence: .daily,
                createdBy: parentId
            ),
            KiddoTask(
                familyId: familyId,
                name: "Read for 15 minutes",
                description: "Any book you like.",
                icon: "book.fill",
                category: .learning,
                pointValue: 15,
                requiresApproval: true,
                assignedChildIds: [childA.id],
                recurrence: .weekdays,
                createdBy: parentId
            )
        ]

        rewards = [
            Reward(
                familyId: familyId,
                name: "Extra screen time",
                description: "15 extra minutes.",
                icon: "tv.fill",
                pointCost: 30,
                requiresApproval: true,
                createdBy: parentId
            ),
            Reward(
                familyId: familyId,
                name: "Choose dessert",
                description: "Pick tonight's treat.",
                icon: "birthday.cake.fill",
                pointCost: 50,
                requiresApproval: true,
                createdBy: parentId
            )
        ]
    }

    private func persistKeepingPassword() {
        guard let snapshot = loadSnapshot() else {
            persist(passwordHash: "")
            return
        }
        persist(passwordHash: snapshot.passwordHash)
    }

    private func persist(passwordHash: String) {
        guard let family, let parent else { return }
        let snapshot = FamilySnapshot(
            family: family,
            parent: parent,
            passwordHash: passwordHash,
            children: children,
            tasks: tasks,
            completions: completions,
            rewards: rewards,
            claims: claims,
            transactions: transactions,
            achievements: achievements
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        dataRevision += 1
    }

    private func loadSnapshot() -> FamilySnapshot? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(FamilySnapshot.self, from: data)
    }

    private func apply(_ snapshot: FamilySnapshot) {
        family = snapshot.family
        parent = snapshot.parent
        children = snapshot.children
        tasks = snapshot.tasks
        completions = snapshot.completions
        rewards = snapshot.rewards
        claims = snapshot.claims
        transactions = snapshot.transactions
        achievements = snapshot.achievements
    }

    private func restoreSession() {
        guard let parentId = UserDefaults.standard.string(forKey: Self.sessionKey),
              let snapshot = loadSnapshot(),
              snapshot.parent.id == parentId else { return }
        apply(snapshot)
    }

    private func restoreSnapshotWithoutSession() {
        // Keep disk data; just clear in-memory session.
    }

    private static func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
