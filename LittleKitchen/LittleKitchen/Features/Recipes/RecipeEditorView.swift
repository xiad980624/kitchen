import SwiftUI

struct RecipeEditorView: View {
    let recipe: Recipe?
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: RecipeCategory = .homestyle
    @State private var duration = 30
    @State private var mainIngredient = ""
    @State private var sideIngredient = ""
    @State private var seasoning = ""
    @State private var firstStep = ""

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _category = State(initialValue: recipe?.category ?? .homestyle)
        _duration = State(initialValue: recipe?.duration ?? 30)
        _mainIngredient = State(initialValue: recipe?.ingredients(for: .main).map(\.name).joined(separator: "、") ?? "")
        _sideIngredient = State(initialValue: recipe?.ingredients(for: .side).map(\.name).joined(separator: "、") ?? "")
        _seasoning = State(initialValue: recipe?.ingredients(for: .seasoning).map(\.name).joined(separator: "、") ?? "")
        _firstStep = State(initialValue: recipe?.steps.joined(separator: "\n") ?? "")
    }

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
        .navigationTitle(recipe == nil ? "新建菜谱" : "编辑菜谱")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let savedRecipe = Recipe(
                        id: recipe?.id ?? UUID(),
                        title: title.isEmpty ? "未命名菜谱" : title,
                        category: category,
                        emoji: recipe?.emoji ?? "🍲",
                        duration: duration,
                        rating: recipe?.rating ?? 0,
                        reviewCount: recipe?.reviewCount ?? 0,
                        voteCount: recipe?.voteCount ?? 0,
                        availability: recipe?.availability ?? .check,
                        ingredients: ingredients,
                        steps: firstStep.split(separator: "\n").map(String.init)
                    )
                    kitchenStore.save(recipe: savedRecipe)
                    coordinator.editingRecipe = nil
                    dismiss()
                    coordinator.showToast("已保存“\(savedRecipe.title)”")
                }
                .fontWeight(.bold)
            }
        }
    }

    private var ingredients: [RecipeIngredient] {
        makeIngredients(mainIngredient, kind: .main)
            + makeIngredients(sideIngredient, kind: .side)
            + makeIngredients(seasoning, kind: .seasoning)
    }

    private func makeIngredients(_ text: String, kind: IngredientKind) -> [RecipeIngredient] {
        text.split(whereSeparator: { $0 == "、" || $0 == "," || $0 == "，" })
            .map { RecipeIngredient(name: String($0).trimmingCharacters(in: .whitespaces), quantity: "", kind: kind) }
            .filter { !$0.name.isEmpty }
    }
}
