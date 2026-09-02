import SwiftUI

struct ProfileHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("林家厨房", systemImage: "house.fill")
                            .font(.title3.weight(.bold))
                        Text("3 位成员 · 一起决定每一餐")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                        Button("邀请成员") {
                            coordinator.showToast("家庭邀请将在服务端同步接入")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(AppTheme.sage)
                }

                Section("家庭") {
                    settingRow("成员", icon: "person.3", detail: "3 人")
                    settingRow("家庭资料", icon: "house", detail: nil)
                    settingRow("邀请成员", icon: "person.badge.plus", detail: nil)
                }

                Section("偏好") {
                    settingRow("通知", icon: "bell", detail: "稍后设置")
                    settingRow("离线数据", icon: "arrow.triangle.2.circlepath", detail: "已保存在本机")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.cream)
            .navigationTitle("我的")
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
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
        }
    }
}
