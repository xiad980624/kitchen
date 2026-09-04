import PhotosUI
import SwiftUI
import UIKit

struct RecipeEditorView: View {
    let recipe: Recipe?
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var categoryChoice: RecipeCategoryChoice
    @State private var customCategoryName = ""
    @State private var duration = 30
    @State private var mainIngredients: [IngredientDraft]
    @State private var sideIngredients: [IngredientDraft]
    @State private var seasoningIngredients: [IngredientDraft]
    @State private var stepDrafts: [RecipeStepDraft]
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _categoryChoice = State(initialValue: recipe?.customCategoryName.map(RecipeCategoryChoice.custom) ?? .builtIn(recipe?.category ?? .homestyle))
        _customCategoryName = State(initialValue: recipe?.customCategoryName ?? "")
        _duration = State(initialValue: recipe?.duration ?? 30)
        _mainIngredients = State(initialValue: Self.drafts(for: recipe, kind: .main))
        _sideIngredients = State(initialValue: Self.drafts(for: recipe, kind: .side))
        _seasoningIngredients = State(initialValue: Self.drafts(for: recipe, kind: .seasoning))
        _stepDrafts = State(initialValue: recipe?.steps.map(RecipeStepDraft.init) ?? [])
        _imageData = State(initialValue: recipe?.imageData)
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("菜谱名称", text: $title)
                    .accessibilityLabel("菜谱名称")
                Picker("分类", selection: $categoryChoice) {
                    ForEach(RecipeCategory.allCases) { category in
                        Text(category.rawValue).tag(RecipeCategoryChoice.builtIn(category))
                    }
                    ForEach(kitchenStore.customCategoryNames, id: \.self) { categoryName in
                        Text(categoryName).tag(RecipeCategoryChoice.custom(categoryName))
                    }
                }
                Button("新建分类") {
                    categoryChoice = .custom("")
                    customCategoryName = ""
                }
                if case .custom = categoryChoice {
                    TextField("分类名称", text: $customCategoryName)
                        .accessibilityLabel("自定义分类名称")
                }
                Stepper("烹饪时长：\(duration) 分钟", value: $duration, in: 5...180, step: 5)
            }

            Section("菜品图片") {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ContentUnavailableView("还没有图片", systemImage: "photo", description: Text("可从相册选择一张菜品图片。"))
                }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(imageData == nil ? "从相册选择" : "更换图片", systemImage: "photo.on.rectangle")
                }
                if imageData != nil {
                    Button("移除图片", role: .destructive) {
                        imageData = nil
                        selectedPhotoItem = nil
                    }
                }
            }

            IngredientEditorSection(title: "主菜", ingredients: $mainIngredients)
            IngredientEditorSection(title: "辅材", ingredients: $sideIngredients)
            IngredientEditorSection(title: "调味料", ingredients: $seasoningIngredients)

            RecipeStepEditorSection(steps: $stepDrafts)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.cream)
        .navigationTitle(recipe == nil ? "新建菜谱" : "编辑菜谱")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveRecipe() }
                    .fontWeight(.bold)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                imageData = compressedImageData(from: data)
            }
        }
        .onChange(of: categoryChoice) { _, choice in
            if case let .custom(categoryName) = choice {
                customCategoryName = categoryName
            }
        }
    }

    private var ingredients: [RecipeIngredient] {
        recipeIngredients(from: mainIngredients, kind: .main)
            + recipeIngredients(from: sideIngredients, kind: .side)
            + recipeIngredients(from: seasoningIngredients, kind: .seasoning)
    }

    private func saveRecipe() {
        let categoryDetails: (RecipeCategory, String?)
        switch categoryChoice {
        case let .builtIn(category):
            categoryDetails = (category, nil)
        case .custom:
            let trimmedName = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            categoryDetails = (.homestyle, trimmedName.isEmpty ? nil : trimmedName)
        }

        let savedRecipe = Recipe(
            id: recipe?.id ?? UUID(),
            title: title.isEmpty ? "未命名菜谱" : title,
            category: categoryDetails.0,
            customCategoryName: categoryDetails.1,
            emoji: recipe?.emoji ?? "🍲",
            imageData: imageData,
            duration: duration,
            rating: recipe?.rating ?? 0,
            reviewCount: recipe?.reviewCount ?? 0,
            voteCount: recipe?.voteCount ?? 0,
            availability: recipe?.availability ?? .check,
            ingredients: ingredients,
            steps: stepDrafts
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        kitchenStore.save(recipe: savedRecipe)
        coordinator.editingRecipe = nil
        dismiss()
        coordinator.showToast("已保存“\(savedRecipe.title)”")
    }

    private func recipeIngredients(from drafts: [IngredientDraft], kind: IngredientKind) -> [RecipeIngredient] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return RecipeIngredient(
                id: draft.id,
                name: name,
                quantity: draft.quantity.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: kind
            )
        }
    }

    private static func drafts(for recipe: Recipe?, kind: IngredientKind) -> [IngredientDraft] {
        recipe?.ingredients(for: kind).map(IngredientDraft.init) ?? []
    }

    private func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maximumDimension: CGFloat = 1_600
        let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resizedImage.jpegData(compressionQuality: 0.78) ?? data
    }
}

private struct IngredientDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var quantity: String

    nonisolated init(id: UUID = UUID(), name: String = "", quantity: String = "") {
        self.id = id
        self.name = name
        self.quantity = quantity
    }

    nonisolated init(_ ingredient: RecipeIngredient) {
        self.init(id: ingredient.id, name: ingredient.name, quantity: ingredient.quantity)
    }
}

private struct RecipeStepDraft: Identifiable, Hashable {
    let id: UUID
    var text: String

    nonisolated init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    nonisolated init(_ text: String) {
        self.init(text: text)
    }
}

private struct IngredientEditorSection: View {
    let title: String
    @Binding var ingredients: [IngredientDraft]

    var body: some View {
        Section(title) {
            if ingredients.isEmpty {
                Text("还没有添加\(title)")
                    .foregroundStyle(AppTheme.muted)
            }

            ForEach($ingredients) { $ingredient in
                HStack(spacing: 10) {
                    TextField("食材名称", text: $ingredient.name)
                        .accessibilityLabel("\(title)名称")
                    TextField("数量", text: $ingredient.quantity)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("\(title)数量")
                }
            }
            .onDelete { offsets in
                ingredients.remove(atOffsets: offsets)
            }

            Button {
                ingredients.append(IngredientDraft())
            } label: {
                Label("添加一项", systemImage: "plus.circle.fill")
            }
        }
    }
}

private struct RecipeStepEditorSection: View {
    @Binding var steps: [RecipeStepDraft]

    var body: some View {
        Section("操作步骤") {
            if steps.isEmpty {
                Text("还没有添加步骤")
                    .foregroundStyle(AppTheme.muted)
            }

            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.sage)
                        .clipShape(Circle())

                    TextField("描述这一步", text: $steps[index].text, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityLabel("第\(index + 1)步")

                    VStack(spacing: 8) {
                        Button {
                            moveStep(at: index, by: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(index == 0)
                        .accessibilityLabel("上移第\(index + 1)步")

                        Button {
                            moveStep(at: index, by: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(index == steps.count - 1)
                        .accessibilityLabel("下移第\(index + 1)步")

                        Button(role: .destructive) {
                            steps.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .accessibilityLabel("删除第\(index + 1)步")
                    }
                    .font(.caption.weight(.bold))
                }
            }

            Button {
                steps.append(RecipeStepDraft())
            } label: {
                Label("添加一步", systemImage: "plus.circle.fill")
            }
        }
    }

    private func moveStep(at index: Int, by offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(destination) else { return }
        steps.swapAt(index, destination)
    }
}

private enum RecipeCategoryChoice: Hashable {
    case builtIn(RecipeCategory)
    case custom(String)
}
