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
    @State private var mainIngredient = ""
    @State private var sideIngredient = ""
    @State private var seasoning = ""
    @State private var firstStep = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _categoryChoice = State(initialValue: recipe?.customCategoryName.map(RecipeCategoryChoice.custom) ?? .builtIn(recipe?.category ?? .homestyle))
        _customCategoryName = State(initialValue: recipe?.customCategoryName ?? "")
        _duration = State(initialValue: recipe?.duration ?? 30)
        _mainIngredient = State(initialValue: recipe?.ingredients(for: .main).map(\.name).joined(separator: "、") ?? "")
        _sideIngredient = State(initialValue: recipe?.ingredients(for: .side).map(\.name).joined(separator: "、") ?? "")
        _seasoning = State(initialValue: recipe?.ingredients(for: .seasoning).map(\.name).joined(separator: "、") ?? "")
        _firstStep = State(initialValue: recipe?.steps.joined(separator: "\n") ?? "")
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
                    .accessibilityLabel("操作步骤")
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
        makeIngredients(mainIngredient, kind: .main)
            + makeIngredients(sideIngredient, kind: .side)
            + makeIngredients(seasoning, kind: .seasoning)
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
            steps: firstStep.split(separator: "\n").map(String.init)
        )
        kitchenStore.save(recipe: savedRecipe)
        coordinator.editingRecipe = nil
        dismiss()
        coordinator.showToast("已保存“\(savedRecipe.title)”")
    }

    private func makeIngredients(_ text: String, kind: IngredientKind) -> [RecipeIngredient] {
        text.split(whereSeparator: { $0 == "、" || $0 == "," || $0 == "，" })
            .map { RecipeIngredient(name: String($0).trimmingCharacters(in: .whitespaces), quantity: "", kind: kind) }
            .filter { !$0.name.isEmpty }
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

private enum RecipeCategoryChoice: Hashable {
    case builtIn(RecipeCategory)
    case custom(String)
}
