import SwiftUI

struct AccountAccessView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case login = "登录"
        case register = "注册"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountSession: AccountSession
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    var body: some View {
        Form {
            Section {
                Picker("方式", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(mode == .login ? "登录家庭" : "创建账号") {
                if mode == .register {
                    TextField("怎么称呼你", text: $displayName)
                        .textContentType(.nickname)
                }
                TextField("邮箱", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                SecureField("密码（至少 8 位）", text: $password)
                    .textContentType(mode == .login ? .password : .newPassword)
            }

            Section {
                Text(mode == .login
                     ? "登录后可加入已有家庭，或创建一个新家庭。"
                     : "账号用于在不同设备之间识别你，并保护家庭数据。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .navigationTitle(mode == .login ? "登录" : "注册")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(accountSession.isWorking ? "处理中" : mode.rawValue) {
                    submit()
                }
                .disabled(!canSubmit || accountSession.isWorking)
            }
        }
        .alert("无法继续", isPresented: Binding(
            get: { accountSession.errorMessage != nil },
            set: { if !$0 { accountSession.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(accountSession.errorMessage ?? "")
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 8 &&
        (mode == .login || !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submit() {
        Task {
            let succeeded: Bool
            switch mode {
            case .login:
                succeeded = await accountSession.login(email: email, password: password)
            case .register:
                succeeded = await accountSession.register(email: email, password: password, displayName: displayName)
            }
            if succeeded { dismiss() }
        }
    }
}

struct HouseholdSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountSession: AccountSession
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @EnvironmentObject private var syncController: KitchenSyncController
    @State private var householdName = ""
    @State private var invitationToken = ""

    var body: some View {
        Form {
            Section {
                TextField("例如：林家厨房", text: $householdName)
                Button("创建并同步本机数据") {
                    Task {
                        guard await accountSession.createHousehold(name: householdName) != nil else { return }
                        await syncController.syncNow(store: kitchenStore, session: accountSession, preference: .preferLocal)
                        dismiss()
                    }
                }
                .disabled(householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || accountSession.isWorking)
            } header: {
                Text("创建一个家庭")
            } footer: {
                Text("创建后会把当前手机的菜谱、冰箱、菜单与待购清单上传为这个家庭的初始数据。")
            }

            Section {
                TextField("输入家庭邀请码", text: $invitationToken)
                    .textInputAutocapitalization(.never)
                Button("加入并获取家庭数据") {
                    Task {
                        guard await accountSession.acceptInvitation(invitationToken.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else { return }
                        await syncController.syncNow(store: kitchenStore, session: accountSession, preference: .preferRemote)
                        dismiss()
                    }
                }
                .disabled(invitationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || accountSession.isWorking)
            } header: {
                Text("加入已有家庭")
            } footer: {
                Text("加入时会以家庭已有数据为准，避免覆盖其他成员的内容。")
            }
        }
        .navigationTitle("设置家庭")
        .alert("无法继续", isPresented: Binding(
            get: { accountSession.errorMessage != nil },
            set: { if !$0 { accountSession.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(accountSession.errorMessage ?? "")
        }
    }
}
