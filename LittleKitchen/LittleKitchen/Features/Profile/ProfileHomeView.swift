import SwiftUI

struct ProfileHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @EnvironmentObject private var accountSession: AccountSession
    @EnvironmentObject private var syncController: KitchenSyncController
    @State private var invitation: InvitationResponse?
    @State private var isShowingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                householdSection
                settingsSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.cream)
            .navigationTitle("我的")
            .sheet(item: $invitation) { invitation in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("把这串邀请码发给要加入的人。他/她登录后，在“设置家庭”中输入即可加入。")
                            .foregroundStyle(AppTheme.muted)
                        Text(invitation.token)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.sageSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        ShareLink(item: invitation.token) {
                            Label("分享邀请码", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle("邀请成员")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { self.invitation = nil }
                        }
                    }
                }
            }
            .confirmationDialog("退出当前账号？", isPresented: $isShowingSignOutConfirmation, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) {
                    accountSession.signOut()
                    coordinator.showToast("已退出登录，本机数据仍会保留")
                }
            } message: {
                Text("退出不会删除这台手机上的菜谱和库存。")
            }
            .alert("同步冲突", isPresented: Binding(
                get: { syncController.conflictMessage != nil },
                set: { if !$0 { syncController.conflictMessage = nil } }
            )) {
                Button("保留本机数据", role: .destructive) {
                    Task { await syncController.resolveConflictKeepingLocal(store: kitchenStore, session: accountSession) }
                }
                Button("采用家庭数据") {
                    Task { await syncController.resolveConflictKeepingRemote(store: kitchenStore, session: accountSession) }
                }
                Button("以后再说", role: .cancel) {}
            } message: {
                Text(syncController.conflictMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let user = accountSession.user {
                VStack(alignment: .leading, spacing: 7) {
                    Label(user.displayName, systemImage: "person.crop.circle.fill")
                        .font(.title3.weight(.bold))
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.vertical, 8)
                .listRowBackground(AppTheme.sage)
            } else {
                NavigationLink {
                    AccountAccessView()
                } label: {
                    Label("登录或注册", systemImage: "person.badge.key")
                }
            }
        }
    }

    @ViewBuilder
    private var householdSection: some View {
        if let household = accountSession.activeHousehold {
            Section("家庭与同步") {
                HStack {
                    Label("当前家庭", systemImage: "house.fill")
                    Spacer()
                    Text(household.name)
                        .foregroundStyle(AppTheme.muted)
                }
                if accountSession.households.count > 1 {
                    Menu {
                        ForEach(accountSession.households) { household in
                            Button(household.name) {
                                accountSession.selectHousehold(household)
                                Task { await syncController.syncNow(store: kitchenStore, session: accountSession, preference: .preferRemote) }
                            }
                        }
                    } label: {
                        Label("切换家庭", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                Button {
                    Task { await syncController.syncNow(store: kitchenStore, session: accountSession) }
                } label: {
                    HStack {
                        Label(syncController.isSyncing ? "正在同步" : "立即同步", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text(syncController.statusMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .disabled(syncController.isSyncing)
                Button {
                    Task { invitation = await accountSession.createInvitation() }
                } label: {
                    Label("邀请成员", systemImage: "person.badge.plus")
                }
                Button("退出登录", role: .destructive) {
                    isShowingSignOutConfirmation = true
                }
            }
        } else if accountSession.isSignedIn {
            Section("家庭与同步") {
                if !accountSession.households.isEmpty {
                    Menu {
                        ForEach(accountSession.households) { household in
                            Button(household.name) {
                                accountSession.selectHousehold(household)
                                Task { await syncController.syncNow(store: kitchenStore, session: accountSession, preference: .preferRemote) }
                            }
                        }
                    } label: {
                        Label("进入已有家庭", systemImage: "house")
                    }
                }
                NavigationLink {
                    HouseholdSetupView()
                } label: {
                    Label("创建或加入家庭", systemImage: "house.badge.plus")
                }
            }
        }
    }

    private var settingsSection: some View {
        Section("偏好") {
            settingRow("通知", icon: "bell", detail: "稍后设置")
            settingRow("本机数据", icon: "externaldrive", detail: "自动保存")
            if accountSession.isSignedIn {
                settingRow("同步服务器", icon: "checkmark.icloud", detail: "www.xdlink.xyz")
            }
        }
    }

    private func settingRow(_ title: String, icon: String, detail: String?) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }
}
