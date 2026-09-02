import SwiftUI

struct PantryHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summary
                    tonightCheck
                    inventory
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.cream.ignoresSafeArea())
            .navigationTitle("冰箱")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        coordinator.showToast("添加食材将在下一轮接入")
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("现有食材")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text("32")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("本周已用 8 样")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(AppTheme.sage)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("需要留意")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Text("3")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.tomato)
                Text("2 样临期")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .appCard()
        }
    }

    private var tonightCheck: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今晚菜单核对")
                .font(.title3.weight(.bold))
            HStack(spacing: 13) {
                RecipeThumbnail(emoji: "🥬", size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("清炒时蔬")
                            .font(.headline)
                        Spacer()
                        AvailabilityPill(availability: .short)
                    }
                    Text("西兰花缺少，已进入待购清单")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                    Button("查看待购清单") {
                        coordinator.showToast("待购清单将在下一轮接入")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.sage)
                }
            }
            .padding(12)
            .appCard()
        }
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("冰箱里的食材")
                .font(.title3.weight(.bold))
            ForEach(SampleData.pantryItems) { item in
                HStack(spacing: 12) {
                    Text(item.emoji)
                        .font(.title2)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.carrotSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.weight(.bold))
                        Text(item.expiryHint ?? item.category)
                            .font(.caption)
                            .foregroundStyle(item.expiryHint == nil ? AppTheme.muted : AppTheme.tomato)
                    }
                    Spacer()
                    Text(item.quantity)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .appCard()
            }
        }
    }
}
