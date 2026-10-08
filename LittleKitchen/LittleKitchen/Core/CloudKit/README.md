# CloudKit 未启用

本项目不启用 CloudKit capability。当前同步方案改为本仓库 [backend](../../../../backend/README.md) 目录中的自建服务：FastAPI、PostgreSQL、Docker Compose，并由宝塔的 Nginx 对外提供 `https://www.xdlink.xyz/api/v1`。

设备端状态继续由 SwiftData 保存，作为离线缓存与未上传修改的本地来源。服务器部署完成后，再在独立分支接入登录、家庭邀请和同步队列。
