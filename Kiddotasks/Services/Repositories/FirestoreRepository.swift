#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

/// Base repository for Firestore CRUD operations
class FirestoreRepository<T: Codable & Identifiable> {
    let db = FirebaseConfig.db
    let collectionName: String
    
    init(collectionName: String) {
        self.collectionName = collectionName
    }
    
    // MARK: - Create
    
    /// Create or overwrite a document
    func create(_ document: T) async throws {
        try db.collection(collectionName).document(String(describing: document.id)).setData(from: document)
    }
    
    // MARK: - Read
    
    /// Get a single document
    func get(id: String) async throws -> T? {
        let snapshot = try await db.collection(collectionName).document(id).getDocument()
        return try snapshot.data(as: T.self)
    }
    
    /// Get all documents in collection
    func getAll() async throws -> [T] {
        let snapshot = try await db.collection(collectionName).getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: T.self) }
    }
    
    /// Query documents with a predicate
    func query(_ predicate: @escaping (T) -> Bool) async throws -> [T] {
        let all = try await getAll()
        return all.filter(predicate)
    }
    
    // MARK: - Update
    
    /// Update specific fields of a document
    func update(id: String, fields: [String: Any]) async throws {
        try await db.collection(collectionName).document(id).updateData(fields)
    }
    
    /// Update entire document
    func update(_ document: T) async throws {
        try db.collection(collectionName).document(String(describing: document.id)).setData(from: document, merge: true)
    }
    
    // MARK: - Delete
    
    /// Delete a document
    func delete(id: String) async throws {
        try await db.collection(collectionName).document(id).delete()
    }
    
    // MARK: - Listeners
    
    /// Listen to a single document with live updates
    func listen(id: String, completion: @escaping (T?) -> Void) -> ListenerRegistration {
        db.collection(collectionName).document(id).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening to document: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let snapshot = snapshot else {
                completion(nil)
                return
            }
            
            let document = try? snapshot.data(as: T.self)
            completion(document)
        }
    }
    
    /// Listen to all documents in collection with live updates
    func listenToAll(completion: @escaping ([T]) -> Void) -> ListenerRegistration {
        db.collection(collectionName).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening to collection: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                completion([])
                return
            }
            
            let documents = snapshot.documents.compactMap { try? $0.data(as: T.self) }
            completion(documents)
        }
    }
    
    /// Listen to collection with query predicate
    func listenFiltered(
        predicate: @escaping (DocumentSnapshot) -> Bool,
        completion: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        db.collection(collectionName).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening to filtered collection: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                completion([])
                return
            }
            
            let documents = snapshot.documents
                .filter(predicate)
                .compactMap { try? $0.data(as: T.self) }
            completion(documents)
        }
    }
    
    // MARK: - Batch Operations
    
    /// Perform multiple writes in a transaction
    func batch(_ operations: @escaping (WriteBatch) throws -> Void) async throws {
        let batch = db.batch()
        try operations(batch)
        try await batch.commit()
    }
}

// MARK: - Paginated Query Support

struct QueryOptions {
    var orderBy: String? = nil
    var descending: Bool = false
    var limit: Int? = nil
    var startAfter: DocumentSnapshot? = nil
    
    static let `default` = QueryOptions()
}

extension FirestoreRepository {
    /// Query with pagination support
    func queryPaginated(options: QueryOptions) async throws -> [T] {
        var query: Query = db.collection(collectionName)
        
        if let orderBy = options.orderBy {
            query = query.order(by: orderBy, descending: options.descending)
        }
        
        if let limit = options.limit {
            query = query.limit(to: limit)
        }
        
        if let startAfter = options.startAfter {
            query = query.start(afterDocument: startAfter)
        }
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: T.self) }
    }
}
#endif
