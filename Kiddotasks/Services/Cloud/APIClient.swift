import Foundation
import FirebaseAuth

/// Thin URLSession client that attaches the Firebase ID token to every request.
/// Base URL: https://kiddotasks-app.web.app
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL = "https://kiddotasks-app.web.app"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Returns the current Firebase ID token, refreshing if needed.
    private func idToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        let result = try await user.getIDToken(forcingRefresh: true)
        return result.token
    }

    private func request(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        var urlComponents = URLComponents(string: baseURL + path)
        guard let url = urlComponents?.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await idToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body { urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
            throw APIError.httpError(httpResponse.statusCode, bodyStr)
        }
        return data
    }

    // MARK: - Endpoints

    /// POST /api/auth/bootstrap — create a family for a newly signed-up parent.
    func bootstrapFamily() async throws -> (familyId: String, kidsPin: String) {
        let data = try await request("POST", "/api/auth/bootstrap", body: [:])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let familyId = json["familyId"] as? String,
              let kidsPin = json["kidsPin"] as? String else {
            throw APIError.invalidResponse
        }
        return (familyId, kidsPin)
    }

    /// GET /api/family
    func getFamily() async throws -> [String: Any] {
        let data = try await request("GET", "/api/family")
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// PUT /api/family
    func updateFamily(name: String?, settings: [String: Any]?) async throws -> Bool {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let settings { body["settings"] = settings }
        let data = try await request("PUT", "/api/family", body: body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// GET /api/children
    func getChildren() async throws -> [[String: Any]] {
        let data = try await request("GET", "/api/children")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["children"] as? [[String: Any]] ?? []
    }

    /// POST /api/children
    func createChild(name: String, avatar: [String: String]?, dateOfBirth: String?) async throws -> [String: Any]? {
        var body: [String: Any] = ["name": name]
        if let avatar { body["avatar"] = avatar }
        if let dateOfBirth { body["dateOfBirth"] = dateOfBirth }
        let data = try await request("POST", "/api/children", body: body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["child"] as? [String: Any]
    }

    /// PUT /api/children/:id
    func updateChild(childId: String, updates: [String: Any]) async throws -> Bool {
        let data = try await request("PUT", "/api/children/\(childId)", body: updates)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// DELETE /api/children/:id
    func deleteChild(childId: String) async throws -> Bool {
        let data = try await request("DELETE", "/api/children/\(childId)")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// GET /api/tasks
    func getTasks() async throws -> [[String: Any]] {
        let data = try await request("GET", "/api/tasks")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["tasks"] as? [[String: Any]] ?? []
    }

    /// POST /api/tasks
    func createTask(_ task: [String: Any]) async throws -> [String: Any]? {
        let data = try await request("POST", "/api/tasks", body: task)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["task"] as? [String: Any]
    }

    /// PUT /api/tasks/:id
    func updateTask(taskId: String, updates: [String: Any]) async throws -> Bool {
        let data = try await request("PUT", "/api/tasks/\(taskId)", body: updates)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// DELETE /api/tasks/:id (soft delete / archive)
    func archiveTask(taskId: String) async throws -> Bool {
        let data = try await request("DELETE", "/api/tasks/\(taskId)")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// POST /api/completions
    func submitCompletion(taskId: String, childId: String, notes: String?, occurrenceKey: String?) async throws -> (completionId: String, requiresApproval: Bool) {
        var body: [String: Any] = ["taskId": taskId, "childId": childId]
        if let notes { body["notes"] = notes }
        if let occurrenceKey { body["occurrenceKey"] = occurrenceKey }
        let data = try await request("POST", "/api/completions", body: body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return (
            completionId: json["completionId"] as? String ?? "",
            requiresApproval: json["requiresApproval"] as? Bool ?? true
        )
    }

    /// POST /api/completions/:id/approve
    func approveCompletion(completionId: String) async throws -> (ok: Bool, pointsAwarded: Int) {
        let data = try await request("POST", "/api/completions/\(completionId)/approve", body: [:])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return (
            ok: json["ok"] as? Bool ?? false,
            pointsAwarded: (json["pointsAwarded"] as? NSNumber)?.intValue ?? 0
        )
    }

    /// POST /api/completions/:id/decline
    func declineCompletion(completionId: String) async throws -> Bool {
        let data = try await request("POST", "/api/completions/\(completionId)/decline", body: [:])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// GET /api/rewards
    func getRewards() async throws -> [[String: Any]] {
        let data = try await request("GET", "/api/rewards")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["rewards"] as? [[String: Any]] ?? []
    }

    /// POST /api/rewards
    func createReward(_ reward: [String: Any]) async throws -> [String: Any]? {
        let data = try await request("POST", "/api/rewards", body: reward)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["reward"] as? [String: Any]
    }

    /// PUT /api/rewards/:id
    func updateReward(rewardId: String, updates: [String: Any]) async throws -> Bool {
        let data = try await request("PUT", "/api/rewards/\(rewardId)", body: updates)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// DELETE /api/rewards/:id
    func deleteReward(rewardId: String) async throws -> Bool {
        let data = try await request("DELETE", "/api/rewards/\(rewardId)")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// POST /api/claims
    func submitClaim(rewardId: String, childId: String, notes: String?) async throws -> String {
        var body: [String: Any] = ["rewardId": rewardId, "childId": childId]
        if let notes { body["notes"] = notes }
        let data = try await request("POST", "/api/claims", body: body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["claimId"] as? String ?? ""
    }

    /// POST /api/claims/:id/approve
    func approveClaim(claimId: String) async throws -> Bool {
        let data = try await request("POST", "/api/claims/\(claimId)/approve", body: [:])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// POST /api/claims/:id/decline
    func declineClaim(claimId: String) async throws -> Bool {
        let data = try await request("POST", "/api/claims/\(claimId)/decline", body: [:])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["ok"] as? Bool ?? false
    }

    /// GET /api/transactions
    func getTransactions(childId: String? = nil) async throws -> [[String: Any]] {
        var path = "/api/transactions"
        if let childId { path += "?childId=\(childId)" }
        let data = try await request("GET", path)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["transactions"] as? [[String: Any]] ?? []
    }

    /// POST /api/family/sync — batch push of the full family snapshot.
    func syncPush(family: [String: Any], removals: [String: Any]?) async throws -> Bool {
        var body: [String: Any] = ["family": family]
        if let removals { body["removals"] = removals }
        _ = try await request("POST", "/api/family/sync", body: body)
        return true
    }
}

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated."
        case .invalidURL: return "Invalid URL."
        case .invalidResponse: return "Invalid response."
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}