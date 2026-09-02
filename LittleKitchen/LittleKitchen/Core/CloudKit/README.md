# CloudKit 预留

本轮不启用 CloudKit capability。设备端状态由 SwiftData 本地快照保存，支持离线读取和写入，并会将旧版 UserDefaults 数据迁移到本地数据存储。

若接入家庭共享，后续同步层将以 actor 串行化访问，并把远端数据投影回 SwiftData 本地缓存。服务端方案与最终发布配置确定后，再在独立分支中接入。
