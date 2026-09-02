# CloudKit 预留

本轮只建立本地样本体验，不启用 CloudKit capability 或持久化模型。

家庭共享将按开发蓝图采用「每个家庭一个 Custom Zone + zone-wide `CKShare`」：同步层以 actor 串行化访问，SwiftData 仅作为设备缓存与离线草稿。最终 Bundle ID 和 CloudKit Container 确定后，再在独立分支中接入。
