import Foundation

enum SampleData {
    static let recipes: [Recipe] = [
        Recipe(
            title: "宫保鸡丁",
            category: .homestyle,
            emoji: "🍗",
            duration: 35,
            rating: 4.8,
            reviewCount: 16,
            voteCount: 2,
            availability: .ready,
            ingredients: [
                RecipeIngredient(name: "鸡腿肉", quantity: "300g", kind: .main),
                RecipeIngredient(name: "花生", quantity: "50g", kind: .side),
                RecipeIngredient(name: "黄瓜", quantity: "半根", kind: .side),
                RecipeIngredient(name: "干辣椒", quantity: "6 个", kind: .seasoning),
                RecipeIngredient(name: "生抽", quantity: "1 汤匙", kind: .seasoning)
            ],
            steps: [
                "鸡腿肉切丁，用少量生抽抓匀腌制 10 分钟。",
                "热锅下油，先将鸡丁炒至变色盛出。",
                "加入干辣椒和花生炒香，放入黄瓜与鸡丁快速翻炒。",
                "倒入调好的酱汁，收汁后即可出锅。"
            ]
        ),
        Recipe(
            title: "番茄牛腩",
            category: .homestyle,
            emoji: "🍅",
            duration: 50,
            rating: 4.9,
            reviewCount: 12,
            voteCount: 3,
            availability: .short,
            ingredients: [
                RecipeIngredient(name: "牛腩", quantity: "500g", kind: .main),
                RecipeIngredient(name: "番茄", quantity: "3 个", kind: .side),
                RecipeIngredient(name: "洋葱", quantity: "半个", kind: .side),
                RecipeIngredient(name: "番茄膏", quantity: "1 汤匙", kind: .seasoning)
            ],
            steps: [
                "牛腩焯水后洗净，加入姜片炖至软烂。",
                "番茄和洋葱炒出香味，加入番茄膏。",
                "倒入牛腩和原汤，小火煮 15 分钟。"
            ]
        ),
        Recipe(
            title: "虾仁蒸蛋",
            category: .quick,
            emoji: "🥚",
            duration: 20,
            rating: 4.8,
            reviewCount: 8,
            voteCount: 1,
            availability: .ready,
            ingredients: [
                RecipeIngredient(name: "鸡蛋", quantity: "3 个", kind: .main),
                RecipeIngredient(name: "虾仁", quantity: "8 只", kind: .side),
                RecipeIngredient(name: "温水", quantity: "250ml", kind: .side),
                RecipeIngredient(name: "香油", quantity: "少许", kind: .seasoning)
            ],
            steps: [
                "鸡蛋加温水打散，过滤后倒入蒸碗。",
                "水开后蒸 8 分钟，放上虾仁再蒸 3 分钟。",
                "淋少许香油即可。"
            ]
        )
    ]

    static let pantryItems: [PantryItem] = [
        PantryItem(name: "鸡蛋", emoji: "🥚", category: "肉蛋奶", quantity: "12 个"),
        PantryItem(name: "鸡腿肉", emoji: "🍗", category: "肉蛋奶", quantity: "500g"),
        PantryItem(name: "黄瓜", emoji: "🥒", category: "蔬菜", quantity: "2 根", expiryHint: "建议两天内吃完"),
        PantryItem(name: "大米", emoji: "🍚", category: "主食", quantity: "2kg"),
        PantryItem(name: "生抽", emoji: "🧂", category: "调味料", quantity: "半瓶")
    ]
}
