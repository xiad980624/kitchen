import Combine
import Foundation

@MainActor
final class AccountSession: ObservableObject {
    @Published private(set) var user: RemoteUser?
    @Published private(set) var households: [RemoteHousehold] = []
    @Published private(set) var activeHousehold: RemoteHousehold?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let api: KitchenAPI
    private let defaults: UserDefaults
    private let tokenKey = "accessToken"
    private let sessionKey = "littleKitchen.accountSession"

    init(api: KitchenAPI? = nil, defaults: UserDefaults = .standard) {
        self.api = api ?? KitchenAPI()
        self.defaults = defaults
        restoreCachedSession()
    }

    var accessToken: String? {
        KeychainStore.value(for: tokenKey)
    }

    var isSignedIn: Bool {
        user != nil && accessToken != nil
    }

    func register(email: String, password: String, displayName: String) async -> Bool {
        await authenticate {
            try await api.register(email: email, password: password, displayName: displayName)
        }
    }

    func login(email: String, password: String) async -> Bool {
        await authenticate {
            try await api.login(email: email, password: password)
        }
    }

    func refreshHouseholds() async {
        guard let token = accessToken else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            households = try await api.households(token: token)
            if let activeID = activeHousehold?.id {
                activeHousehold = households.first(where: { $0.id == activeID })
            }
            if activeHousehold == nil, households.count == 1 {
                activeHousehold = households[0]
            }
            saveCachedSession()
        } catch {
            errorMessage = message(for: error)
        }
    }

    func createHousehold(name: String) async -> RemoteHousehold? {
        guard let token = accessToken else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let household = try await api.createHousehold(name: name, token: token)
            households.append(household)
            activeHousehold = household
            saveCachedSession()
            return household
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func acceptInvitation(_ invitationToken: String) async -> RemoteHousehold? {
        guard let token = accessToken else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let household = try await api.acceptInvitation(invitationToken, token: token)
            households.append(household)
            activeHousehold = household
            saveCachedSession()
            return household
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func selectHousehold(_ household: RemoteHousehold) {
        activeHousehold = household
        saveCachedSession()
    }

    func createInvitation() async -> InvitationResponse? {
        guard let token = accessToken, let household = activeHousehold else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            return try await api.createInvitation(householdID: household.id, token: token)
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func signOut() {
        KeychainStore.removeValue(for: tokenKey)
        user = nil
        households = []
        activeHousehold = nil
        defaults.removeObject(forKey: sessionKey)
    }

    private func authenticate(_ action: () async throws -> AuthenticationResponse) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let response = try await action()
            user = response.user
            KeychainStore.save(response.accessToken, for: tokenKey)
            households = try await api.households(token: response.accessToken)
            activeHousehold = households.count == 1 ? households[0] : nil
            saveCachedSession()
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    private func restoreCachedSession() {
        guard accessToken != nil,
              let data = defaults.data(forKey: sessionKey),
              let cached = try? JSONDecoder().decode(CachedSession.self, from: data) else { return }
        user = cached.user
        activeHousehold = cached.activeHousehold
    }

    private func saveCachedSession() {
        guard let user else { return }
        let cached = CachedSession(user: user, activeHousehold: activeHousehold)
        defaults.set(try? JSONEncoder().encode(cached), forKey: sessionKey)
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "网络连接失败，请检查网络后重试。"
    }
}

private struct CachedSession: Codable {
    let user: RemoteUser
    let activeHousehold: RemoteHousehold?
}
