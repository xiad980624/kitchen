import SwiftUI

struct RecipeEditorView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: RecipeCategory = .homestyle
    @State private var duration = 30
    @State private var mainIngredient = ""
    @State private var sideIngredient = ""
    @State private var seasoning = ""
    @State private var firstStep = ""

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("菜谱名称", text: $title)
                    .accessibilityLabel("菜谱名称")
                Picker("分类", selection: $category) {
                    ForEach(RecipeCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                Stepper("烹饪时长：\(duration) 分钟", value: $duration, in: 5...180, step: 5)
            }

            Section("主菜") {
                TextField("例如：鸡腿肉 300g", text: $mainIngredient)
            }

            Section("辅材") {
                TextField("例如：黄瓜 半根", text: $sideIngredient)
            }

            Section("调味料") {
                TextField("例如：生抽 1 汤匙", text: $seasoning)
            }

            Section("操作步骤") {
                TextEditor(text: $firstStep)
                    .frame(minHeight: 110)
                    .accessibilityLabel("第一步")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.cream)
        .navigationTitle("新建菜谱")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    dismiss()
                    coordinator.showToast(title.isEmpty ? "已保存草稿" : "已保存“\(title)”草稿")
                }
                .fontWeight(.bold)
            }
        }
    }
}
