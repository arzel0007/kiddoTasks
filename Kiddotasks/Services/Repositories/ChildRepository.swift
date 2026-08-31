#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

/// Repository for managing Child entities
class ChildRepository: FirestoreRepository<Child> {
    init() {
        super.init(collectionName: FirestoreCollections.children)
    }
    
    // MARK: - Family-specific queries
    
    /// Get all children in a family
    func getChildrenInFamily(_ familyId: String) async throws -> [Child] {
        let snapshot = try await db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Child.self) }
    }
    
    /// Listen to all children in a family
    func listenToChildrenInFamily(_ familyId: String, completion: @escaping ([Child]) -> Void) -> ListenerRegistration {
        db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to family children: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion([])
                    return
                }
                
                let children = try? snapshot.documents.compactMap { try $0.data(as: Child.self) }
                completion(children ?? [])
            }
    }
    
    // MARK: - Points operations
    
    /// Update a child's point balance
    func updatePoints(_ childId: String, points: Int) async throws {
        try await update(id: childId, fields: [
            "activePoints": points,
            "updatedAt": Timestamp()
        ])
    }
    
    /// Increment a child's total earned points
    func incrementTotalEarned(_ childId: String, by amount: Int) async throws {
        try await update(id: childId, fields: [
            "totalPointsEarned": FieldValue.increment(Int64(amount)),
            "updatedAt": Timestamp()
        ])
    }
    
    // MARK: - Child creation
    
    /// Create a new child in a family
    func createChild(name: String, familyId: String, avatar: ChildAvatar = .default) async throws -> Child {
        let child = Child(
            name: name,
            familyId: familyId,
            avatar: avatar,
            activePoints: 0,
            totalPointsEarned: 0
        )
        try await create(child)
        return child
    }
    
    // MARK: - Validation
    
    /// Check if a child belongs to a family
    func childBelongsToFamily(_ childId: String, familyId: String) async throws -> Bool {
        guard let child = try await get(id: childId) else {
            return false
        }
        return child.familyId == familyId
    }
}
#endif
