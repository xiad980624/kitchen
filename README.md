# 小家厨房

面向同住家庭的点菜、菜单、冰箱与待购协作 iOS App。

## 当前状态

工程基座使用 SwiftUI、iOS 17+ 与 XCTest。当前提供四个可浏览的本地样本入口，尚未接入 CloudKit、账号或真实持久化。

## 本地运行

1. 用 Xcode 打开 `LittleKitchen/LittleKitchen.xcodeproj`。
2. 选择任一 iOS 17 或更高版本的模拟器，运行 `LittleKitchen` scheme。
3. 在开始 CloudKit 迭代前，将 `com.xd.LittleKitchen` 替换为已注册的最终 Bundle ID，并配置对应的 Apple Developer Team 和 CloudKit Container。

产品范围与架构决策见 [iOS 开发蓝图](docs/ios-development-blueprint.md)。
