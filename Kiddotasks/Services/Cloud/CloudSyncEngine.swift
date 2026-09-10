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

    /// Signs in an existing account. Pushes any dirty local work first, then
    /// pulls the family — so switching devices never discards unpushed edits.
    /// If cloud parent/family docs are missing (e.g. after Reset all data),
    /// re-bootstraps a family for this Auth user so the account is usable again.
    func signIn(email: String, password: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else { throw FirebaseError.authNotAvailable }
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw FirebaseError.invalidCredentials
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }

        if store.family != nil, hasUnsyncedLocalChanges {
            try? await pushSnapshotAndWait()
        }

        let snapshot: FamilySnapshot
        do {
            snapshot = try await fetchSnapshot(uid: uid, email: email)
        } catch {
            // Auth user exists but family/parent docs are gone (Reset wiped them).
            // Create a fresh cloud family for this account instead of dead-ending.
            if Self.isMissingCloudFamily(error) {
                try await rebootstrapFamilyAfterMissingDocs(uid: uid, email: email)
                startListening()
                startPeriodicRefresh()
                status = .signedIn
                return
            }
            throw error
        }

        if hasUnsyncedLocalChanges {
            // Still dirty — keep local, wire listeners, let retries finish.
            startListening()
            startPeriodicRefresh()
            status = .pending
            return
        }
        applyFromCloud(snapshot)
        startListening()
        startPeriodicRefresh()
        status = .signedIn
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    /// Recreates family + parent docs for an Auth user whose cloud family was
    /// deleted (Reset all data). Seeds a clean local store and pushes starter content.
    private func rebootstrapFamilyAfterMissingDocs(uid: String, email: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
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
            ])
        guard let data = callResult.data as? [String: Any],
              let familyId = data["familyId"] as? String else {
            throw FirebaseError.operationFailed("Could not restore your family. Try again.")
        }
        let pin = (data["kidsStationPIN"] as? String) ?? "1234"
        let familyCode = data["familyCode"] as? String

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
        let message = error.localizedDescription.lowercased()
        return message.contains("not found") || message.contains("no document")
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
            return try JSONSerialization.jsonObject(with: data)
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
