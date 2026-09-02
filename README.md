# 小家厨房（kitchen）

面向同住家庭的点菜、菜单、冰箱与待购协作 iOS App。

## 当前状态

工程基座使用 SwiftUI、SwiftData、iOS 17+ 与 XCTest。菜谱、点菜、个人评分、今日菜单和冰箱库存保存在设备本地；待购清单会根据当天已安排菜单自动更新。旧版 UserDefaults 数据会在首次启动时迁移到本地数据存储。尚未接入 CloudKit、账号或家庭共享。

## 本地运行

1. 用 Xcode 打开 `LittleKitchen/LittleKitchen.xcodeproj`。
2. 选择任一 iOS 17 或更高版本的模拟器，运行 `LittleKitchen` scheme。
3. 在开始 CloudKit 迭代前，将 `com.xd.LittleKitchen` 替换为已注册的最终 Bundle ID，并配置对应的 Apple Developer Team 和 CloudKit Container。

产品范围与架构决策见 [iOS 开发蓝图](docs/ios-development-blueprint.md)。
