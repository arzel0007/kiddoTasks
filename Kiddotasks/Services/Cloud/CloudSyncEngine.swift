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
    case error(String)

    var isSignedIn: Bool {
        switch self {
        case .signedIn, .syncing:
            return true
        default:
            return false
        }
    }
}

/// Drives Firebase Authentication + Firestore synchronization for a family.
///
/// When Firebase is configured (`GoogleService-Info.plist` present and the
/// Firebase SDK linked) this engine is the source of truth:
///
///   - **Sign up / sign in** with email + password.
///   - **Pull** the whole family from Firestore on sign-in, so an existing
///     parent who switches phones gets their family, tasks, rewards, points and
///     history back automatically.
///   - **Push** every local mutation upward (debounced) through the
///     `pushFamilySnapshot` callable, which writes with server privileges.
///   - **Refresh** from the cloud when the family doc changes (via a snapshot
///     listener) and every 20 seconds while signed in.
///
/// When Firebase is not configured the engine is a no-op and the app keeps
/// working in local-first mode, exactly as before.
@MainActor
final class CloudSyncEngine {
    private unowned let store: LocalFamilyDataStore

    private var familyListener: Any?
    private var refreshTask: Task<Void, Never>?
    private var pendingPush: Task<Void, Never>?
    private var isRefreshing = false
    private var lastPushedRevision: Int = -1
    private var lastFetchedFingerprint: String?

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

    /// Wires the store's change hook and restores an existing Auth session.
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

    /// Restores a previously signed-in Firebase user, pulling their family from
    /// the cloud (works when this is a brand-new device).
    func autoRestoreIfPossible() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable, let user = Auth.auth().currentUser else {
            status = isAvailable ? .signedOut : .unavailable
            return
        }
        do {
            let snapshot = try await fetchSnapshot(uid: user.uid, email: user.email ?? "")
            applyFromCloud(snapshot)
            startListening()
            startPeriodicRefresh()
            status = .signedIn
        } catch {
            // No usable family for this account yet; treat as signed out.
            try? Auth.auth().signOut()
            status = .signedOut
        }
        #endif
    }

    // MARK: - Auth (email + password)

    /// Creates the Firebase account, bootstraps the family server-side, seeds
    /// the local store with matching IDs, and pushes the starter content.
    /// Returns the generated Kids Station PIN.
    func signUp(email: String, password: String, familyName: String, parentName: String) async throws -> String {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable else { throw FirebaseError.authNotAvailable }

        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = authResult.user.uid

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

        // Seed local state with the real cloud IDs (parentId == Firebase UID).
        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: familyId,
            parentId: uid,
            familyName: familyName,
            parentName: parentName,
            email: email
        )

        // Keep the cloud-generated Kids PIN in sync locally.
        store.family?.settings.kidsStationPIN = pin
        store.family?.updatedAt = Date()

        try await pushSnapshotAndWait()
        startListening()
        startPeriodicRefresh()
        status = .signedIn
        return pin
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    /// Signs in an existing account and pulls the family down from Firestore
    /// — this is what makes "existing user on a new device" work.
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
        let snapshot = try await fetchSnapshot(uid: uid, email: email)
        applyFromCloud(snapshot)
        startListening()
        startPeriodicRefresh()
        status = .signedIn
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }

    /// Signs out of Firebase Auth and clears the local session.
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
        lastFetchedFingerprint = nil
        lastPushedRevision = -1
        isRefreshing = false
        store.signOut()
        status = isAvailable ? .signedOut : .unavailable
    }
// MARK: - Sync

    /// Pulls the latest family state from the cloud and applies it locally if
    /// there are no unsynced local changes. Safe to call often.
    func refreshFromCloud() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        guard isAvailable,
              let user = Auth.auth().currentUser,
              !isRefreshing,
              store.dataRevision == lastPushedRevision else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let email = user.email ?? store.parent?.email ?? ""
            let snapshot = try await fetchSnapshot(uid: user.uid, email: email)
            let fingerprint = fingerprint(of: snapshot)
            guard fingerprint != lastFetchedFingerprint else { return }
            applyFromCloud(snapshot)
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
            try? await self.pushSnapshotAndWait()
        }
        #endif
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
        pendingPush?.cancel()

        status = .syncing
        do {
            let payload = try makePushPayload(snapshot)
            _ = try await Functions.functions()
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
            lastPushedRevision = store.dataRevision
            status = .signedIn
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
        #endif
    }

    private func applyFromCloud(_ snapshot: FamilySnapshot) {
        store.applyRemote(snapshot)
        lastFetchedFingerprint = fingerprint(of: snapshot)
        // Keep the push watermark in step so scheduled refreshes aren't blocked.
        lastPushedRevision = store.dataRevision
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
        return try snapshot.documents.compactMap { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return try decodeJSON(type, from: data)
        }
        #else
        return []
        #endif
    }

    // MARK: - Serialization helpers

    private func makePushPayload(_ snapshot: FamilySnapshot) throws -> [String: Any] {
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
        ]
        #else
        throw FirebaseError.authNotAvailable
        #endif
    }
/// Decodes a model from raw Firestore data by round-tripping through JSON.
    /// Dates come back as ISO-8601 strings; Firestore timestamps are converted
    /// first. Explicit field-by-field mapping is avoided so adding a field to a
    /// model doesn't require new mapping code.
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
        default:
            return String(describing: value)
        }
        #else
        return String(describing: value)
        #endif
    }

    /// A stable fingerprint of a snapshot used to detect remote changes.
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