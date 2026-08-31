#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

/// Repository for managing Point transactions and balances
class PointRepository: FirestoreRepository<PointTransaction> {
    init() {
        super.init(collectionName: FirestoreCollections.pointTransactions)
    }
    
    // MARK: - Transaction creation
    
    /// Record a point transaction
    func recordTransaction(
        familyId: String,
        childId: String,
        amount: Int,
        type: TransactionType,
        description: String,
        relatedId: String? = nil,
        createdBy: String? = nil
    ) async throws -> PointTransaction {
        let transaction = PointTransaction(
            familyId: familyId,
            childId: childId,
            amount: amount,
            type: type,
            relatedId: relatedId,
            description: description,
            createdBy: createdBy
        )
        try await create(transaction)
        return transaction
    }
    
    // MARK: - Transaction queries
    
    /// Get all transactions for a child
    func getTransactionsForChild(_ childId: String, familyId: String) async throws -> [PointTransaction] {
        let snapshot = try await db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .whereField("childId", isEqualTo: childId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: PointTransaction.self) }
    }
    
    /// Listen to transactions for a child
    func listenToTransactionsForChild(
        _ childId: String,
        familyId: String,
        completion: @escaping ([PointTransaction]) -> Void
    ) -> ListenerRegistration {
        db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .whereField("childId", isEqualTo: childId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to child transactions: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion([])
                    return
                }
                
                let transactions = try? snapshot.documents.compactMap { try $0.data(as: PointTransaction.self) }
                completion(transactions ?? [])
            }
    }
    
    /// Get transactions by type
    func getTransactionsByType(_ type: TransactionType, childId: String, familyId: String) async throws -> [PointTransaction] {
        let snapshot = try await db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .whereField("childId", isEqualTo: childId)
            .whereField("type", isEqualTo: type.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: PointTransaction.self) }
    }
    
    // MARK: - Balance calculation
    
    /// Calculate current point balance from transaction history
    func calculateBalance(childId: String, familyId: String) async throws -> PointBalance {
        let transactions = try await getTransactionsForChild(childId, familyId: familyId)
        var balance = PointBalance(childId: childId, familyId: familyId)
        
        for transaction in transactions where !transaction.isReversed {
            balance.applyTransaction(transaction)
        }
        
        return balance
    }
    
    /// Get total points earned by a child
    func getTotalEarned(childId: String, familyId: String) async throws -> Int {
        let transactions = try await getTransactionsForChild(childId, familyId: familyId)
        return transactions
            .filter { !$0.isReversed && $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Get total points spent/deducted
    func getTotalSpent(childId: String, familyId: String) async throws -> Int {
        let transactions = try await getTransactionsForChild(childId, familyId: familyId)
        return transactions
            .filter { !$0.isReversed && $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    // MARK: - Reversal
    
    /// Reverse a transaction (creates reversal transaction)
    func reverseTransaction(_ transactionId: String, by parentId: String) async throws -> PointTransaction {
        guard let originalTransaction = try await get(id: transactionId) else {
            throw FirebaseError.documentNotFound
        }
        
        // Create reversal
        let reversalTransaction = originalTransaction.createReversal(by: parentId)
        try await create(reversalTransaction)
        
        // Mark original as reversed
        try await update(id: transactionId, fields: [
            "isReversed": true,
            "reversalTransactionId": reversalTransaction.id
        ])
        
        return reversalTransaction
    }
    
    // MARK: - Idempotency
    
    /// Check if a transaction already exists (for duplicate prevention)
    func transactionExists(
        relatedId: String,
        type: TransactionType,
        childId: String,
        familyId: String
    ) async throws -> Bool {
        let snapshot = try await db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .whereField("childId", isEqualTo: childId)
            .whereField("type", isEqualTo: type.rawValue)
            .whereField("relatedId", isEqualTo: relatedId)
            .whereField("isReversed", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    /// Get existing transaction for a related ID
    func getExistingTransaction(
        relatedId: String,
        type: TransactionType,
        childId: String,
        familyId: String
    ) async throws -> PointTransaction? {
        let snapshot = try await db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .whereField("childId", isEqualTo: childId)
            .whereField("type", isEqualTo: type.rawValue)
            .whereField("relatedId", isEqualTo: relatedId)
            .whereField("isReversed", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()
        
        return try snapshot.documents.first?.data(as: PointTransaction.self)
    }
}
#endif
