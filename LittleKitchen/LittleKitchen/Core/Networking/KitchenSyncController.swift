import Combine
import Foundation

enum SyncPreference {
    case automatic
    case preferLocal
    case preferRemote
}

@MainActor
final class KitchenSyncController: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var statusMessage = "尚未同步"
    @Published var conflictMessage: String?

    private let api: KitchenAPI
    private let defaults: UserDefaults

    init(api: KitchenAPI? = nil, defaults: UserDefaults = .standard) {
        self.api = api ?? KitchenAPI()
        self.defaults = defaults
    }

    func syncNow(
        store: LocalKitchenStore,
        session: AccountSession,
        preference: SyncPreference = .automatic
    ) async {
        guard let token = session.accessToken, let household = session.activeHousehold else {
            statusMessage = "登录并选择家庭后才可同步"
            return
        }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let response = try await api.pull(householdID: household.id, token: token)
            let remoteRecord = response.changes.first { $0.resource == "kitchen_snapshot" && $0.itemID == "current" }
            let localSnapshot = store.syncSnapshot
            let localData = try KitchenAPI.snapshotData(localSnapshot)
            let savedData = defaults.data(forKey: snapshotKey(for: household.id))
            let savedRevision = defaults.integer(forKey: revisionKey(for: household.id))

            guard let remoteRecord, let payload = remoteRecord.payload else {
                try await push(snapshot: localSnapshot, household: household, baseRevision: 0, token: token)
                statusMessage = "已将本机数据同步到\(household.name)"
                return
            }

            let remoteSnapshot = try KitchenAPI.snapshot(from: payload)
            switch preference {
            case .preferRemote:
                apply(remoteSnapshot, revision: remoteRecord.revision, to: store, householdID: household.id)
                statusMessage = "已获取\(household.name)的最新数据"
            case .preferLocal:
                try await push(snapshot: localSnapshot, household: household, baseRevision: remoteRecord.revision, token: token)
                statusMessage = "已上传本机数据"
            case .automatic:
                if savedData == nil {
                    apply(remoteSnapshot, revision: remoteRecord.revision, to: store, householdID: household.id)
                    statusMessage = "已获取\(household.name)的最新数据"
                } else if savedData == localData {
                    if remoteRecord.revision > savedRevision {
                        apply(remoteSnapshot, revision: remoteRecord.revision, to: store, householdID: household.id)
                        statusMessage = "已同步其他成员的更新"
                    } else {
                        statusMessage = "已是最新数据"
                    }
                } else if remoteRecord.revision == savedRevision {
                    try await push(snapshot: localSnapshot, household: household, baseRevision: savedRevision, token: token)
                    statusMessage = "本机更改已同步"
                } else {
                    conflictMessage = "本机和其他设备都修改了数据。为避免覆盖，请先选择保留哪一份数据。"
                    statusMessage = "发现同步冲突"
                }
            }
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? "同步失败，请稍后重试。"
        }
    }

    func resolveConflictKeepingLocal(store: LocalKitchenStore, session: AccountSession) async {
        await syncNow(store: store, session: session, preference: .preferLocal)
        conflictMessage = nil
    }

    func resolveConflictKeepingRemote(store: LocalKitchenStore, session: AccountSession) async {
        await syncNow(store: store, session: session, preference: .preferRemote)
        conflictMessage = nil
    }

    private func push(snapshot: KitchenSnapshot, household: RemoteHousehold, baseRevision: Int, token: String) async throws {
        let response = try await api.push(snapshot: snapshot, householdID: household.id, baseRevision: baseRevision, token: token)
        guard response.conflicts.isEmpty, let record = response.accepted.first else {
            conflictMessage = "其他设备已先更新数据，请选择要保留的版本。"
            return
        }
        defaults.set(record.revision, forKey: revisionKey(for: household.id))
        defaults.set(try KitchenAPI.snapshotData(snapshot), forKey: snapshotKey(for: household.id))
    }

    private func apply(_ snapshot: KitchenSnapshot, revision: Int, to store: LocalKitchenStore, householdID: String) {
        store.replaceLocalData(with: snapshot)
        defaults.set(revision, forKey: revisionKey(for: householdID))
        defaults.set(try? KitchenAPI.snapshotData(snapshot), forKey: snapshotKey(for: householdID))
    }

    private func revisionKey(for householdID: String) -> String {
        "littleKitchen.sync.revision.\(householdID)"
    }

    private func snapshotKey(for householdID: String) -> String {
        "littleKitchen.sync.snapshot.\(householdID)"
    }
}
