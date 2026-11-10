import Foundation

enum KitchenAPIError: LocalizedError {
    case invalidResponse
    case server(message: String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器没有返回有效结果，请稍后重试。"
        case .server(let message):
            return message
        case .decoding:
            return "服务器数据无法读取，请更新 App 后重试。"
        }
    }
}

struct RemoteUser: Codable, Equatable {
    let id: String
    let email: String
    let displayName: String

    private enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
    }
}

struct RemoteHousehold: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
}

struct AuthenticationResponse: Codable {
    let accessToken: String
    let user: RemoteUser

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

struct InvitationResponse: Codable, Identifiable {
    let token: String
    let householdID: String

    var id: String { token }

    private enum CodingKeys: String, CodingKey {
        case token
        case householdID = "household_id"
    }
}

struct RemoteSyncRecord: Decodable {
    let resource: String
    let itemID: String
    let revision: Int
    let payload: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case resource, revision, payload
        case itemID = "item_id"
    }
}

struct SyncPullResponse: Decodable {
    let changes: [RemoteSyncRecord]
}

struct SyncPushResponse: Decodable {
    let accepted: [RemoteSyncRecord]
    let conflicts: [SyncConflict]
}

struct SyncConflict: Decodable {
    let resource: String
    let itemID: String

    private enum CodingKeys: String, CodingKey {
        case resource
        case itemID = "item_id"
    }
}

enum JSONValue: Codable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw KitchenAPIError.decoding }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct KitchenAPI {
    private let baseURL = URL(string: "https://www.xdlink.xyz/api/v1")!

    func register(email: String, password: String, displayName: String) async throws -> AuthenticationResponse {
        try await request(
            path: "auth/register",
            method: "POST",
            body: ["email": email, "password": password, "display_name": displayName],
            token: nil
        )
    }

    func login(email: String, password: String) async throws -> AuthenticationResponse {
        try await request(path: "auth/login", method: "POST", body: ["email": email, "password": password], token: nil)
    }

    func households(token: String) async throws -> [RemoteHousehold] {
        try await request(path: "households", method: "GET", body: Optional<[String: String]>.none, token: token)
    }

    func createHousehold(name: String, token: String) async throws -> RemoteHousehold {
        try await request(path: "households", method: "POST", body: ["name": name], token: token)
    }

    func acceptInvitation(_ invitationToken: String, token: String) async throws -> RemoteHousehold {
        try await request(
            path: "households/invitations/\(invitationToken)/accept",
            method: "POST",
            body: Optional<[String: String]>.none,
            token: token
        )
    }

    func createInvitation(householdID: String, token: String) async throws -> InvitationResponse {
        try await request(
            path: "households/\(householdID)/invitations",
            method: "POST",
            body: ["expires_in_days": 7],
            token: token
        )
    }

    func pull(householdID: String, token: String) async throws -> SyncPullResponse {
        var components = URLComponents(url: baseURL.appending(path: "sync/pull"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "household_id", value: householdID)]
        return try await request(url: components.url!, method: "GET", body: Optional<[String: String]>.none, token: token)
    }

    func push(snapshot: KitchenSnapshot, householdID: String, baseRevision: Int, token: String) async throws -> SyncPushResponse {
        let snapshotData = try Self.snapshotEncoder.encode(snapshot)
        let payload = try JSONDecoder().decode(JSONValue.self, from: snapshotData)
        let request = SyncPushRequest(
            householdID: householdID,
            changes: [SyncPushChange(resource: "kitchen_snapshot", itemID: "current", payload: payload, baseRevision: baseRevision)]
        )
        return try await self.request(path: "sync/push", method: "POST", body: request, token: token)
    }

    static func snapshot(from payload: JSONValue) throws -> KitchenSnapshot {
        let data = try snapshotEncoder.encode(payload)
        return try JSONDecoder().decode(KitchenSnapshot.self, from: data)
    }

    static func snapshotData(_ snapshot: KitchenSnapshot) throws -> Data {
        try snapshotEncoder.encode(snapshot)
    }

    private static let snapshotEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private func request<Request: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Request?,
        token: String?
    ) async throws -> Response {
        try await request(url: baseURL.appending(path: path), method: method, body: body, token: token)
    }

    private func request<Request: Encodable, Response: Decodable>(
        url: URL,
        method: String,
        body: Request?,
        token: String?
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw KitchenAPIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerError.self, from: data))?.detail
            throw KitchenAPIError.server(message: message ?? "请求失败（\(httpResponse.statusCode)）")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw KitchenAPIError.decoding
        }
    }
}

private struct ServerError: Decodable { let detail: String }

private struct SyncPushRequest: Encodable {
    let householdID: String
    let changes: [SyncPushChange]

    private enum CodingKeys: String, CodingKey {
        case householdID = "household_id"
        case changes
    }
}

private struct SyncPushChange: Encodable {
    let resource: String
    let itemID: String
    let payload: JSONValue
    let baseRevision: Int

    private enum CodingKeys: String, CodingKey {
        case resource, payload
        case itemID = "item_id"
        case baseRevision = "base_revision"
    }
}
