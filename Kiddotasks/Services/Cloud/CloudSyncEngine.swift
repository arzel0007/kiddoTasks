import Foundation
import CryptoKit

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
#endif

/// Current cloud connectivity state, surfaced to the UI.
enum CloudSyncStatus: Equatable {
    case unavailable
    case signedOut
    case signedIn
    case syncing
    case pending
    case error(String)

    var isSignedIn: Bool {
        switch self {
        case .signedIn, .syncing, .pending, .error:
            return true
        default:
            return false
        }
    }
}

/// Drives Firebase Authentication + Firestore synchronization for a family.
///
/// Invariants that prevent data loss:
/// 1. Local unpushed work is never overwritten by a cloud pull.
/// 2. Push failures are visible and retried (never silently dropped).
/// 3. Local deletes are tombstoned, pushed to the server, then acknowledged.
/// 4. A co-parent can join via family code with their own email/password.
@MainActor
final class CloudSyncEngine {
    private unowned let store: LocalFamilyDataStore

    private var familyListener: Any?
    private var refreshTask: Task<Void, Never>?
    private var pendingPush: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var isRefreshing = false
    private var isPushing = false
    private var pushRetryAttempt = 0
    private var lastFetchedFingerprint: String?

    /// True when local mutations exist that have not been acknowledged by a
    /// successful push. Never apply a cloud pull over this state.
    var hasUnsyncedLocalChanges: Bool { store.hasPendingPush }

    /// True when the Firebase SDK is linked AND the app was configured with a
    /// GoogleService-Info.plist at launch.
    var isAvailable: Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    /// True when an account is signed in with Firebase Auth.
    var isSignedIn: Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        return Auth.auth().currentUser != nil
        #else
        return false
        #endif
    }

    /// Current sync status, observable by the UI.
    private(set) var status: CloudSyncStatus = .unavailable

    init(store: LocalFamilyDataStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    func start() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else {
            status = .unavailable
            return
        }
        store.onLocalChanges = { [weak self] in
            Task { @MainActor [weak self] in
                self?.schedulePush()
            }
        }
        status = Auth.auth().currentUser == nil ? .signedOut : .signedIn
        if Auth.auth().currentUser != nil {
            Task { [weak self] in
                await self?.autoRestoreIfPossible()
            }
        }
        #else
        status = .unavailable
        #endif
    }

    /// Restores a previously signed-in Firebase user.
    ///
    /// If local work is still pending a push, it is pushed FIRST so a relaunch
    /// can never clobber un-synced edits with a stale cloud snapshot.
    func autoRestoreIfPossible() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable, let user = Auth.auth().currentUser else {
            status = isAvailable ? .signedOut : .unavailable
            return
        }
        do {
            if store.family != nil, hasUnsyncedLocalChanges {
                status = .pending
                do {
                    try await pushSnapshotAndWait()
                } catch {
                    // Keep local work; still wire listeners so we can retry later.
                    startListening()
                    startPeriodicRefresh()
                    scheduleRetryPush()
                    status = .error(error.localizedDescription)
                    return
                }
            }
            let snapshot = try await fetchSnapshot(uid: user.uid, email: user.email ?? "")
            if hasUnsyncedLocalChanges {
                // Push reported success but local is dirty again (raced edit).
                // Keep local; do not apply remote over it.
                status = .pending
                startListening()
                startPeriodicRefresh()
                return
            }
            applyFromCloud(snapshot)
            startListening()
            startPeriodicRefresh()
            status = .signedIn
        } catch {
            // Fetch failed. If we have usable local family data, keep it and
            // retry instead of signing the parent out (that caused data loss).
            if store.family != nil {
                startListening()
                startPeriodicRefresh()
                if hasUnsyncedLocalChanges {
                    scheduleRetryPush()
                    status = .pending
                } else {
                    status = .error(error.localizedDescription)
                }
                return
            }
            try? Auth.auth().signOut()
            status = .signedOut
        }
        #endif
    }

    // MARK: - Auth (email + password)

    func signUp(email: String, password: String, familyName: String, parentName: String) async throws -> String {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else { throw FirebaseError.authNotAvailable }

        let uid: String
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            uid = authResult.user.uid
        } catch {
            // Account already exists (common after Reset all data, which wipes
            // family docs but leaves the Firebase Auth user). Recover by signing
            // in — signIn re-bootstraps a family if the docs are gone.
            if Self.isEmailAlreadyInUse(error) {
                try await signIn(email: email, password: password)
                return store.family?.settings.kidsStationPIN ?? "1234"
            }
            throw error
        }

        let callResult = try await Functions.functions()
            .httpsCallable("bootstrapFamily")
            .call([
                "familyName": familyName,
                "displayName": parentName,
                "email": email,
            ])
        guard let data = callResult.data as? [String: Any],
              let familyId = data["familyId"] as? String else {
            throw FirebaseError.operationFailed("Family bootstrap failed")
        }
        let pin = (data["kidsStationPIN"] as? String) ?? "1234"
        let familyCode = data["familyCode"] as? String

        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: familyId,
            parentId: uid,
            familyName: familyName,
            parentName: parentName,
            email: email
        )

        store.family?.settings.kidsStationPIN = pin
        if let familyCode, let family = store.family {
            family.familyCode = familyCode
        }
        store.family?.updatedAt = Date()

        try await pushSnapshotAndWait()
        store.markPushAcknowledged()
        startListening()
        startPeriodicRefresh()
        status = .signedIn
        return pin
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    /// Signs in an existing account.
    ///
    /// Always ends with a loaded local family, or throws. Never returns
    /// success while the store is unauthenticated — that dismissed the sheet
    /// and bounced the user back to Welcome.
    func signIn(email: String, password: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else { throw FirebaseError.authNotAvailable }
        print("[Auth] signIn begin email=\(email)")
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            print("[Auth] Firebase Auth ok uid=\(Auth.auth().currentUser?.uid ?? "?")")
        } catch {
            print("[Auth] Firebase Auth failed: \(error.localizedDescription)")
            throw FirebaseError.invalidCredentials
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }

        // Keep unpushed local work when we have a family; never block restore
        // when local is empty (post-reset) — cloud must win in that case.
        if store.family != nil, hasUnsyncedLocalChanges {
            print("[Auth] pushing dirty local work before pull")
            try? await pushSnapshotAndWait()
        }

        let snapshot: FamilySnapshot
        do {
            snapshot = try await fetchSnapshot(uid: uid, email: email)
            print("[Auth] fetched family=\(snapshot.family.id) kids=\(snapshot.children.count) tasks=\(snapshot.tasks.count)")
        } catch {
            print("[Auth] fetch failed: \(error.localizedDescription)")
            // Only recreate family docs when they are actually missing/unreadable.
            // A network blip must NOT create a duplicate family.
            if Self.isMissingCloudFamily(error) {
                print("[Auth] missing cloud family — rebootstrap")
                try await rebootstrapFamilyAfterMissingDocs(
                    uid: uid,
                    email: email,
                    reason: error.localizedDescription
                )
                startListening()
                startPeriodicRefresh()
                status = .signedIn
                guard store.isAuthenticated else {
                    throw FirebaseError.operationFailed("Could not restore your family. Try again.")
                }
                print("[Auth] rebootstrap done family=\(store.family?.id ?? "nil")")
                return
            }
            throw error
        }

        if store.family == nil || !hasUnsyncedLocalChanges {
            applyFromCloud(snapshot)
        } else {
            // Still dirty after push attempt — keep local, but only succeed
            // if this device actually has a signed-in family to show.
            print("[Auth] still dirty after push; keeping local")
            startListening()
            startPeriodicRefresh()
            status = .pending
            guard store.isAuthenticated else {
                throw FirebaseError.operationFailed(
                    "Could not finish sign-in. Check your connection and try again."
                )
            }
            return
        }

        startListening()
        startPeriodicRefresh()
        status = .signedIn
        guard store.isAuthenticated else {
            throw FirebaseError.operationFailed("Sign-in did not load your family. Try again.")
        }
        print("[Auth] signIn success family=\(store.family?.id ?? "nil")")
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    /// Recreates family + parent docs for an Auth user whose cloud family was
    /// deleted or is unreadable.
    ///
    /// Uses `forceNewFamily: true` so the server always issues a brand-new
    /// familyId and wipes leftover docs for the previous family. Reusing the
    /// old id after a partial reset is what caused old kids/tasks to resurrect
    /// and duplicate next to newly created ones.
    private func rebootstrapFamilyAfterMissingDocs(uid: String, email: String, reason: String = "") async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        print("[Auth] rebootstrap start reason=\(reason)")
        let displayName = store.parent?.displayName ?? "Parent"
        let familyName = store.family?.name ?? "Our family"
        store.clearSyncMeta()
        store.deleteAllLocalData()

        let callResult = try await Functions.functions()
            .httpsCallable("bootstrapFamily")
            .call([
                "familyName": familyName,
                "displayName": displayName,
                "email": email,
                "forceNewFamily": true,
            ])
        guard let data = callResult.data as? [String: Any],
              let familyId = data["familyId"] as? String else {
            print("[Auth] bootstrapFamily bad response: \(String(describing: callResult.data))")
            throw FirebaseError.operationFailed("Could not restore your family. Try again.")
        }
        let pin = (data["kidsStationPIN"] as? String) ?? "1234"
        let familyCode = data["familyCode"] as? String
        print("[Auth] bootstrapFamily ok familyId=\(familyId)")

        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: familyId,
            parentId: uid,
            familyName: familyName,
            parentName: displayName,
            email: email
        )
        store.family?.settings.kidsStationPIN = pin
        if let familyCode, let family = store.family {
            family.familyCode = familyCode
        }
        try await pushSnapshotAndWait()
        store.markPushAcknowledged()
        #endif
    }

    private static func isEmailAlreadyInUse(_ error: Error) -> Bool {
        let nsError = error as NSError
        // FIRAuthErrorCodeEmailAlreadyInUse = 17007
        if nsError.domain.contains("FIRAuthErrorDomain"), nsError.code == 17007 {
            return true
        }
        let message = error.localizedDescription.lowercased()
        return message.contains("already in use")
            || message.contains("already exists")
            || message.contains("email address is already")
    }

    private static func isMissingCloudFamily(_ error: Error) -> Bool {
        if let firebaseError = error as? FirebaseError {
            switch firebaseError {
            case .documentNotFound, .invalidFamily:
                return true
            default:
                return false
            }
        }
        let nsError = error as NSError
        // Firestore not-found
        if nsError.domain.contains("FIRFirestoreErrorDomain"), nsError.code == 5 {
            return true
        }
        let message = error.localizedDescription.lowercased()
        return message.contains("no document")
            || message.contains("document not found")
            || message.contains("not found")
    }

    /// Co-parent joins an existing cloud family with their own Firebase account.
    func joinFamilyWithCode(code: String, email: String, password: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else { throw FirebaseError.authNotAvailable }

        // Create the co-parent account if needed, then sign in.
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            // Account may already exist — fall through to sign-in.
        }
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw FirebaseError.invalidCredentials
        }
        guard Auth.auth().currentUser != nil else {
            throw FirebaseError.notAuthenticated
        }

        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let result = try await Functions.functions()
            .httpsCallable("joinFamilyWithCode")
            .call(["familyCode": normalized])
        guard let data = result.data as? [String: Any],
              let familyId = data["familyId"] as? String else {
            throw FirebaseError.operationFailed("Join failed")
        }

        // Fresh co-parent join: local store should become the cloud family.
        // Drop any unrelated local cache so the pull is authoritative.
        store.clearSyncMeta()
        store.deleteAllLocalData()

        let snapshot = try await fetchSnapshot(
            uid: Auth.auth().currentUser?.uid ?? "",
            email: email
        )
        _ = familyId
        applyFromCloud(snapshot)
        startListening()
        startPeriodicRefresh()
        status = .signedIn
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        if isAvailable {
            try? Auth.auth().signOut()
        }
        #endif
        #if canImport(FirebaseFirestore)
        (familyListener as? ListenerRegistration)?.remove()
        #endif
        familyListener = nil
        refreshTask?.cancel()
        refreshTask = nil
        pendingPush?.cancel()
        pendingPush = nil
        retryTask?.cancel()
        retryTask = nil
        lastFetchedFingerprint = nil
        pushRetryAttempt = 0
        isRefreshing = false
        isPushing = false
        store.signOut()
        status = isAvailable ? .signedOut : .unavailable
    }

    /// Keeps the server-side kidsPins index in sync after a parent changes the PIN.
    func syncKidsPINIndex(pin: String) async throws {
        #if canImport(FirebaseFunctions)
        guard isAvailable else { return }
        _ = try await Functions.functions()
            .httpsCallable("updateKidsStationPIN")
            .call(["pin": pin])
        #endif
    }

    /// Kids PIN unlock: pulls a family snapshot via `openKidsSession` without
    /// requiring the parent password (shared iPad).
    func openKidsSession(pin: String) async throws -> Bool {
        #if canImport(FirebaseFunctions)
        guard isAvailable else { return false }
        let result = try await Functions.functions()
            .httpsCallable("openKidsSession")
            .call(["pin": pin])
        guard let data = result.data as? [String: Any],
              let familyId = data["familyId"] as? String else {
            return false
        }
        // Decode snapshot pieces into the local store so Kids UI can run.
        try applyKidsSessionPayload(data, familyId: familyId)
        return true
        #else
        return false
        #endif
    }

    private func applyKidsSessionPayload(_ data: [String: Any], familyId: String) throws {
        #if canImport(FirebaseFirestore)
        func decodeList<T: Decodable>(_ type: T.Type, key: String) -> [T] {
            guard let arr = data[key] as? [[String: Any]] else { return [] }
            return arr.compactMap { dict in
                try? decodeJSON(type, from: dict)
            }
        }
        guard var familyDict = data["family"] as? [String: Any] else {
            throw FirebaseError.invalidFamily
        }
        familyDict["id"] = familyId
        let family = try decodeJSON(Family.self, from: familyDict)
        let children = decodeList(Child.self, key: "children")
        let tasks = decodeList(KiddoTask.self, key: "tasks")
        let completions = decodeList(TaskCompletion.self, key: "completions")
        let rewards = decodeList(Reward.self, key: "rewards")
        let claims = decodeList(RewardClaim.self, key: "claims")
        let transactions = decodeList(PointTransaction.self, key: "transactions")
        let achievements = decodeList(Achievement.self, key: "achievements")

        // Lightweight parent shell so the store treats the device as signed-in
        // for kids-only mutations (completions/claims need a family, not a real UID).
        let parent = Parent(
            id: "kids-session",
            email: "",
            displayName: "Kids Station",
            familyId: familyId,
            role: .owner,
            lastSignInAt: Date()
        )
        let snapshot = FamilySnapshot(
            family: family,
            parent: parent,
            passwordHash: "",
            children: children,
            tasks: tasks,
            completions: completions,
            rewards: rewards,
            claims: claims,
            transactions: transactions,
            achievements: achievements
        )
        store.clearSyncMeta()
        store.applyRemote(snapshot)
        store.markPushAcknowledged()
        #endif
    }

    func deleteCloudData() async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else { return }
        defer { store.clearSyncMeta() }
        _ = try await Functions.functions()
            .httpsCallable("deleteFamilyData")
            .call([:])
        #endif
    }

    func sendPasswordReset(email: String) async throws {
        #if canImport(FirebaseAuth)
        guard isAvailable else {
            throw FirebaseError.authNotAvailable
        }
        try await Auth.auth().sendPasswordReset(withEmail: email)
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    // MARK: - Sync

    /// Pulls the latest family state when it is safe to apply.
    func refreshFromCloud() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable,
              let user = Auth.auth().currentUser,
              !isRefreshing else { return }
        // Never pull over unpushed local work.
        guard !hasUnsyncedLocalChanges else {
            scheduleRetryPush()
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let email = user.email ?? store.parent?.email ?? ""
            let snapshot = try await fetchSnapshot(uid: user.uid, email: email)
            let incomingFingerprint = fingerprint(of: snapshot)
            if let last = lastFetchedFingerprint, incomingFingerprint == last {
                return
            }
            // Stale-guard: skip if remote stamp is not newer than what we saw.
            if let remoteStamp = snapshot.family.serverUpdatedAt,
               let lastStamp = store.lastSeenServerUpdatedAt,
               remoteStamp <= lastStamp,
               store.family != nil {
                lastFetchedFingerprint = incomingFingerprint
                return
            }
            guard !hasUnsyncedLocalChanges else { return }
            applyFromCloud(snapshot)
            lastFetchedFingerprint = incomingFingerprint
        } catch {
            // Transient network or rules failure; keep current local state.
        }
        #endif
    }

    private func schedulePush() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable, Auth.auth().currentUser != nil, store.family != nil else { return }
        pendingPush?.cancel()
        pendingPush = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.performPushWithRetryBudget(attempt: 0)
        }
        #endif
    }

    private func scheduleRetryPush() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        retryTask?.cancel()
        let delays: [UInt64] = [2, 8, 30, 60]
        let index = min(pushRetryAttempt, delays.count - 1)
        let nanos = delays[index] * 1_000_000_000
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled, let self else { return }
            await self.performPushWithRetryBudget(attempt: self.pushRetryAttempt + 1)
        }
        #endif
    }

    private func performPushWithRetryBudget(attempt: Int) async {
        guard hasUnsyncedLocalChanges else { return }
        do {
            try await pushSnapshotAndWait()
            pushRetryAttempt = 0
        } catch {
            pushRetryAttempt = attempt
            status = .error(error.localizedDescription)
            scheduleRetryPush()
        }
    }

    /// Pushes the current local snapshot to the cloud right now.
    func pushSnapshot() async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        try await pushSnapshotAndWait()
        #endif
    }

    private func pushSnapshotAndWait() async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable,
              let user = Auth.auth().currentUser,
              let snapshot = store.currentSnapshot() else { return }
        guard !isPushing else { return }
        isPushing = true
        defer { isPushing = false }

        pendingPush?.cancel()
        status = .syncing
        do {
            let removals = store.pendingRemovals
            let payload = try makePushPayload(snapshot, removals: removals)
            let result = try await Functions.functions()
                .httpsCallable("pushFamilySnapshot")
                .call(payload)

            // Keep the parent doc fresh (rules allow only these two fields).
            if let parent = store.parent {
                try? await Firestore.firestore()
                    .collection(FirestoreCollections.parents)
                    .document(user.uid)
                    .updateData([
                        "displayName": parent.displayName,
                        "lastSignInAt": FieldValue.serverTimestamp(),
                    ])
            }

            // Ack tombstones the server confirmed.
            if let data = result.data as? [String: Any],
               let deleted = data["deleted"] as? [String: Any] {
                store.acknowledgeRemovals(
                    children: deleted["children"] as? [String] ?? [],
                    tasks: deleted["tasks"] as? [String] ?? [],
                    completions: deleted["completions"] as? [String] ?? [],
                    rewards: deleted["rewards"] as? [String] ?? [],
                    claims: deleted["claims"] as? [String] ?? [],
                    transactions: deleted["transactions"] as? [String] ?? [],
                    achievements: deleted["achievements"] as? [String] ?? []
                )
            } else {
                store.acknowledgeRemovals(
                    children: removals.children,
                    tasks: removals.tasks,
                    completions: removals.completions,
                    rewards: removals.rewards,
                    claims: removals.claims,
                    transactions: removals.transactions,
                    achievements: removals.achievements
                )
            }

            store.markPushAcknowledged()
            status = .signedIn
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
        #endif
    }

    private func applyFromCloud(_ snapshot: FamilySnapshot) {
        let incomingFingerprint = fingerprint(of: snapshot)
        let previous = store.currentSnapshot()
        store.applyRemote(snapshot)
        lastFetchedFingerprint = incomingFingerprint

        guard let previous else { return }
        let childNames = Dictionary(
            uniqueKeysWithValues: snapshot.children.map { ($0.id, $0.name) }
        )
        let taskNames = Dictionary(
            uniqueKeysWithValues: snapshot.tasks.map { ($0.id, $0.name) }
        )
        let rewardNames = Dictionary(
            uniqueKeysWithValues: snapshot.rewards.map { ($0.id, ($0.name, $0.pointCost)) }
        )
        let events = FamilyChangeDetector.detectChanges(
            older: previous,
            newer: snapshot,
            childNames: childNames,
            taskNames: taskNames,
            rewardNames: rewardNames
        )
        LocalFamilyNotifier.notify(
            events,
            enabled: snapshot.family.settings.enableNotifications
        )
    }

    // MARK: - Cloud reads

    private func fetchSnapshot(uid: String, email: String) async throws -> FamilySnapshot {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        let db = Firestore.firestore()

        guard let familyId = try await fetchFamilyId(for: uid) else {
            throw FirebaseError.documentNotFound
        }
        guard let family = try await fetchFamily(id: familyId) else {
            throw FirebaseError.invalidFamily
        }

        async let children = fetch(Child.self, collection: FirestoreCollections.children, familyId: familyId)
        async let tasks = fetch(KiddoTask.self, collection: FirestoreCollections.tasks, familyId: familyId)
        async let completions = fetch(TaskCompletion.self, collection: FirestoreCollections.taskCompletions, familyId: familyId)
        async let rewards = fetch(Reward.self, collection: FirestoreCollections.rewards, familyId: familyId)
        async let claims = fetch(RewardClaim.self, collection: FirestoreCollections.rewardClaims, familyId: familyId)
        async let transactions = fetch(PointTransaction.self, collection: FirestoreCollections.pointTransactions, familyId: familyId)
        async let achievements = fetch(Achievement.self, collection: FirestoreCollections.achievements, familyId: familyId)

        let parentDoc = try? await db.collection(FirestoreCollections.parents).document(uid).getDocument()
        let parentData = parentDoc?.data() ?? [:]
        let parent = Parent(
            id: uid,
            email: email,
            displayName: parentData["displayName"] as? String ?? "Parent",
            familyId: familyId,
            role: .owner,
            lastSignInAt: Date()
        )

        return FamilySnapshot(
            family: family,
            parent: parent,
            passwordHash: "",
            children: try await children,
            tasks: try await tasks,
            completions: try await completions,
            rewards: try await rewards,
            claims: try await claims,
            transactions: try await transactions,
            achievements: try await achievements
        )
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    private func fetchFamilyId(for uid: String) async throws -> String? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        let doc = try await Firestore.firestore()
            .collection(FirestoreCollections.parents)
            .document(uid)
            .getDocument()
        return doc.data()?["familyId"] as? String
        #else
        return nil
        #endif
    }

    private func fetchFamily(id: String) async throws -> Family? {
        #if canImport(FirebaseFirestore)
        let doc = try await Firestore.firestore()
            .collection(FirestoreCollections.families)
            .document(id)
            .getDocument()
        guard doc.exists, var data = doc.data() else { return nil }
        data["id"] = doc.documentID
        return try decodeJSON(Family.self, from: data)
        #else
        return nil
        #endif
    }

    private func fetch<T: Decodable>(
        _ type: T.Type,
        collection: String,
        familyId: String
    ) async throws -> [T] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection(collection)
            .whereField("familyId", isEqualTo: familyId)
            .getDocuments()
        // Skip undecodable docs instead of failing the entire pull.
        return snapshot.documents.compactMap { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return try? decodeJSON(type, from: data)
        }
        #else
        return []
        #endif
    }

    // MARK: - Serialization helpers

    private func makePushPayload(
        _ snapshot: FamilySnapshot,
        removals: (children: [String], tasks: [String], completions: [String], rewards: [String], claims: [String], transactions: [String], achievements: [String])
    ) throws -> [String: Any] {
        #if canImport(FirebaseFirestore)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        func enc<T: Encodable>(_ value: T) throws -> Any {
            let data = try encoder.encode(value)
            let json = try JSONSerialization.jsonObject(with: data)
            return strippingEmbeddedPhotoData(json)
        }

        /// Drop `photoData` when a Storage `photoURL` exists so snapshot pushes
        /// stay small; clients load images from Storage instead.
        func strippingEmbeddedPhotoData(_ any: Any) -> Any {
            if var dict = any as? [String: Any] {
                if let url = dict["photoURL"] as? String, !url.isEmpty {
                    dict.removeValue(forKey: "photoData")
                }
                return dict.mapValues { strippingEmbeddedPhotoData($0) }
            }
            if let array = any as? [Any] {
                return array.map { strippingEmbeddedPhotoData($0) }
            }
            return any
        }

        return [
            "familyId": snapshot.family.id,
            "family": try enc(snapshot.family),
            "children": try enc(snapshot.children),
            "tasks": try enc(snapshot.tasks),
            "completions": try enc(snapshot.completions),
            "rewards": try enc(snapshot.rewards),
            "claims": try enc(snapshot.claims),
            "transactions": try enc(snapshot.transactions),
            "achievements": try enc(snapshot.achievements),
            "removedChildren": removals.children,
            "removedTasks": removals.tasks,
            "removedCompletions": removals.completions,
            "removedRewards": removals.rewards,
            "removedClaims": removals.claims,
            "removedTransactions": removals.transactions,
            "removedAchievements": removals.achievements,
        ]
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        #if canImport(FirebaseFirestore)
        let clean = dict.mapValues { value in jsonSafe(value) }
        let data = try JSONSerialization.data(withJSONObject: clean)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    private func jsonSafe(_ value: Any) -> Any {
        #if canImport(FirebaseFirestore)
        switch value {
        case let ts as Timestamp:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: ts.dateValue())
        case let date as Date:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: date)
        case let dict as [String: Any]:
            return dict.mapValues { jsonSafe($0) }
        case let array as [Any]:
            return array.map { jsonSafe($0) }
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue
            }
            return number
        case is NSNull, is Void:
            return NSNull()
        case let data as Data:
            return data.base64EncodedString()
        case let data as NSData:
            return data.base64EncodedString()
        default:
            return String(describing: value)
        }
        #else
        return String(describing: value)
        #endif
    }

    /// Fingerprint of the incoming cloud snapshot (computed before local apply
    /// mutates shared model instances).
    private func fingerprint(of snapshot: FamilySnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Live refresh wiring

    private func startListening() {
        #if canImport(FirebaseFirestore)
        guard isAvailable, familyListener == nil,
              let uid = Auth.auth().currentUser?.uid else { return }
        Task { [weak self] in
            guard let self,
                  let familyId = try? await self.fetchFamilyId(for: uid) else { return }
            self.familyListener = Firestore.firestore()
                .collection(FirestoreCollections.families)
                .document(familyId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard snapshot?.exists == true else { return }
                    Task { [weak self] in
                        await self?.refreshFromCloud()
                    }
                }
        }
        #endif
    }

    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled, let self else { break }
                #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
                await self.refreshFromCloud()
                #else
                break
                #endif
            }
        }
    }
}
