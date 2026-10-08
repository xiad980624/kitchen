import SwiftUI
import UniformTypeIdentifiers

struct ProfileHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @State private var backupDocument: KitchenBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var importedBackup: KitchenBackupDocument?
    @State private var isShowingRestoreConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("我的厨房", systemImage: "house.fill")
                            .font(.title3.weight(.bold))
                        Text("只保存在这台设备 · 不会自动上传")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(AppTheme.sage)
                }

                Section("本机") {
                    settingRow("本机使用", icon: "iphone", detail: "已启用")
                    settingRow("本地数据", icon: "externaldrive", detail: "仅此设备")
                }

                Section("偏好") {
                    settingRow("通知", icon: "bell", detail: "稍后设置")
                    settingRow("离线数据", icon: "arrow.triangle.2.circlepath", detail: "已保存在本机")
                }

                Section("本地备份") {
                    Button {
                        backupDocument = KitchenBackupDocument(snapshot: kitchenStore.backupSnapshot)
                        isExportingBackup = true
                    } label: {
                        Label("导出备份到文件", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImportingBackup = true
                    } label: {
                        Label("从备份文件恢复", systemImage: "square.and.arrow.down")
                    }

                    Text("数据只保存在这台设备。导出后可自己保存备份；恢复会替换当前所有菜谱、菜单、库存和待购清单。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.cream)
            .navigationTitle("我的")
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                if case .success = result {
                    coordinator.showToast("本地备份已导出")
                }
            }
            .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    loadBackup(from: url)
                case .failure:
                    coordinator.showToast("未能打开备份文件")
                }
            }
            .alert("恢复本地数据？", isPresented: $isShowingRestoreConfirmation, presenting: importedBackup) { backup in
                Button("取消", role: .cancel) {
                    importedBackup = nil
                }
                Button("恢复并替换", role: .destructive) {
                    kitchenStore.restore(snapshot: backup.snapshot)
                    importedBackup = nil
                    coordinator.showToast("已从备份恢复本地数据")
                }
            } message: { _ in
                Text("当前设备里的全部数据会被这份备份替换，此操作无法撤销。")
            }
        }
    }

    private var backupFilename: String {
        "小家厨房备份-\(Date.now.formatted(.iso8601.year().month().day()))"
    }

    private func loadBackup(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            importedBackup = try KitchenBackupDocument(data: Data(contentsOf: url))
            isShowingRestoreConfirmation = true
        } catch {
            coordinator.showToast("备份文件无法使用")
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
