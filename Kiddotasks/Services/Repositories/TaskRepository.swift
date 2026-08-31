#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

/// Repository for managing Task entities
class TaskRepository: FirestoreRepository<KiddoTask> {
    init() {
        super.init(collectionName: FirestoreCollections.tasks)
    }
    
    // MARK: - Family-specific queries
    
    /// Get all active tasks in a family
    func getTasksInFamily(_ familyId: String, activeOnly: Bool = true) async throws -> [KiddoTask] {
        var query: Query = db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
        
        if activeOnly {
            query = query.whereField("isActive", isEqualTo: true)
        }
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: KiddoTask.self) }
    }
    
    /// Listen to tasks in a family
    func listenToTasksInFamily(_ familyId: String, activeOnly: Bool = true, completion: @escaping ([KiddoTask]) -> Void) -> ListenerRegistration {
        var query: Query = db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
        
        if activeOnly {
            query = query.whereField("isActive", isEqualTo: true)
        }
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening to family tasks: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                completion([])
                return
            }
            
            let tasks = try? snapshot.documents.compactMap { try $0.data(as: KiddoTask.self) }
            completion(tasks ?? [])
        }
    }
    
    // MARK: - Child-specific queries
    
    /// Get tasks assigned to a specific child
    func getTasksForChild(_ childId: String, familyId: String) async throws -> [KiddoTask] {
        let allFamilyTasks = try await getTasksInFamily(familyId, activeOnly: true)
        return allFamilyTasks.filter { $0.isAssignedTo(childId) }
    }
    
    /// Listen to tasks assigned to a child
    func listenToTasksForChild(_ childId: String, familyId: String, completion: @escaping ([KiddoTask]) -> Void) -> ListenerRegistration {
        return listenToTasksInFamily(familyId, activeOnly: true) { allTasks in
            let assignedTasks = allTasks.filter { $0.isAssignedTo(childId) }
            completion(assignedTasks)
        }
    }
    
    // MARK: - Category queries
    
    /// Get tasks by category
    func getTasksByCategory(_ category: TaskCategory, familyId: String) async throws -> [KiddoTask] {
        let snapshot = try await db.collection(collectionName)
            .whereField("familyId", isEqualTo: familyId)
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: KiddoTask.self) }
    }
    
    // MARK: - Task creation
    
    /// Create a new task
    func createTask(
        familyId: String,
        name: String,
        description: String = "",
        icon: String = "checkmark.circle",
        category: TaskCategory = .household,
        pointValue: Int = 10,
        requiresApproval: Bool = false,
        assignedChildIds: [String] = [],
        recurrence: TaskRecurrence = .oneTime,
        createdBy: String
    ) async throws -> KiddoTask {
        let task = KiddoTask(
            familyId: familyId,
            name: name,
            description: description,
            icon: icon,
            category: category,
            pointValue: pointValue,
            requiresApproval: requiresApproval,
            assignedChildIds: assignedChildIds,
            recurrence: recurrence,
            isActive: true,
            createdBy: createdBy
        )
        try await create(task)
        return task
    }
    
    // MARK: - Task updates
    
    /// Update task (increments version)
    func updateTask(_ task: KiddoTask) async throws {
        task.version += 1
        task.updatedAt = Date()
        try await update(task)
    }
    
    /// Archive a task (soft delete)
    func archiveTask(_ taskId: String) async throws {
        try await update(id: taskId, fields: [
            "isActive": false,
            "updatedAt": Timestamp()
        ])
    }
    
    // MARK: - Assignment
    
    /// Assign task to children
    func assignTaskToChildren(_ taskId: String, childIds: [String]) async throws {
        try await update(id: taskId, fields: [
            "assignedChildIds": childIds,
            "updatedAt": Timestamp()
        ])
    }
    
    // MARK: - Validation
    
    /// Check if task belongs to family
    func taskBelongsToFamily(_ taskId: String, familyId: String) async throws -> Bool {
        guard let task = try await get(id: taskId) else {
            return false
        }
        return task.familyId == familyId
    }
}
#endif
