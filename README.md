# 小家厨房（kitchen）

面向同住家庭的点菜、菜单、冰箱与待购协作 iOS App。

## 当前状态

工程基座使用 SwiftUI、SwiftData、iOS 17+ 与 XCTest。菜谱、点菜、个人评分、指定日期的菜单（含排序与完成状态）、冰箱库存（可新增、编辑、移除）和菜谱修改记录均保存在设备本地；待购清单会根据当天已安排菜单自动更新，并支持手动补充、勾选和移除。主要页面会随本地数据更新显示空状态，并提供基础 VoiceOver 标签。旧版 UserDefaults 数据会在首次启动时迁移到本地数据存储。尚未接入账号、服务端同步或家庭共享。

## 本地运行

1. 用 Xcode 打开 `LittleKitchen/LittleKitchen.xcodeproj`。
2. 选择任一 iOS 17 或更高版本的模拟器，运行 `LittleKitchen` scheme。
3. 工程当前使用 Bundle ID `com.xiad980624.LittleKitchen`。设备端数据保存不依赖 iCloud；后续接入自建服务端时再配置服务端地址与身份认证。

产品范围与架构决策见 [iOS 开发蓝图](docs/ios-development-blueprint.md)。
