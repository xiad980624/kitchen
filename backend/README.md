# 小家厨房同步服务

这是和 iOS 工程一起保存的服务端代码，不是 Codex 云端文件。它运行在你的阿里云服务器上，并由宝塔已有的 Nginx 将 `https://www.xdlink.xyz/api/v1` 转发给它。

## 本轮具备的能力

- 邮箱注册、登录和 Bearer Token 登录态。
- 创建家庭、家庭创建者生成邀请、受邀成员接受邀请。
- 菜谱、库存、日历和待购清单的增量同步。第一版 iOS 可先用一个 `kitchen_snapshot` 同步完整本地快照，后续再按菜谱、库存、日历和待购清单拆分；客户端带上本地版本号，服务器发现已被别人修改时会返回冲突记录，不会静默覆盖。
- 菜谱封面与步骤图片上传到服务器磁盘；图片仅同一家庭的已登录成员可读取。
- PostgreSQL 数据库只在 Docker 内部网络开放，不暴露 5432 公网端口。

当前 iOS App 还没有连接这些接口。这是有意拆开的两步：先让服务器能稳定运行、可验证，再在下一条分支把 iOS 的本地数据接到同步队列，避免出现“手机一升级，服务器也坏了”这种难排查的问题。

## 接口一览

所有业务接口都在 `/api/v1` 下。除了注册、登录和健康检查，其余接口均需请求头 `Authorization: Bearer <access_token>`。

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| `POST` | `/auth/register` | 注册并返回登录令牌 |
| `POST` | `/auth/login` | 登录并返回登录令牌 |
| `GET` | `/auth/me` | 获取当前用户 |
| `GET` / `POST` | `/households` | 查询或创建家庭 |
| `POST` | `/households/{id}/invitations` | 由家庭创建者生成邀请 |
| `POST` | `/households/invitations/{token}/accept` | 接受邀请 |
| `POST` / `GET` | `/sync/push`、`/sync/pull` | 上传本地更改、拉取增量更改 |
| `POST` / `GET` | `/media/images`、`/media/images/{id}` | 上传或读取菜谱图片 |

## 部署到你的宝塔服务器

前提：`www.xdlink.xyz` 已解析到服务器、HTTPS 已可用；宝塔中的该站点目前的根路径可继续保持原样。以下操作需要在服务器的终端中执行，或由你登录宝塔后让我在可见界面操作。不要把宝塔或服务器密码发到聊天里。

1. 在服务器中取得本仓库，并进入后端目录：

   ```bash
   git clone https://github.com/xiad980624/kitchen.git /www/wwwroot/littlekitchen
   cd /www/wwwroot/littlekitchen/backend
   ```

   如果之前已经克隆过仓库，改为执行：

   ```bash
   cd /www/wwwroot/littlekitchen
   git pull --ff-only origin main
   cd backend
   ```

2. 在宝塔的软件商店安装 Docker（如尚未安装），然后建立只放在服务器上的配置文件：

   ```bash
   cp .env.example .env
   openssl rand -base64 48
   openssl rand -base64 48
   ```

   打开 `.env`，把 `POSTGRES_PASSWORD` 和 `DATABASE_URL` 中的同一段密码替换为第一个随机值；把 `JWT_SECRET` 替换为第二个随机值。两者都不要提交进 Git。

3. 启动服务：

   ```bash
   docker compose up -d --build
   curl http://127.0.0.1:8000/health
   ```

   最后一条应返回 `{"status":"ok"}`。首次启动会自动创建数据库表。

4. 在宝塔的 `www.xdlink.xyz` 网站中添加反向代理，代理名称可写“小家厨房 API”：

   - 代理目录：`/api/`
   - 目标 URL：`http://127.0.0.1:8000`
   - 保留 WebSocket 支持即可；上传大小限制设为至少 `10 MB`。

   如果你使用的是“配置文件”方式，站点 HTTPS server 块内对应内容为：

   ```nginx
   location /api/ {
       proxy_pass http://127.0.0.1:8000;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       client_max_body_size 10m;
   }
   ```

5. 从外网验证：

   ```bash
   curl https://www.xdlink.xyz/api/v1/health
   ```

   这里也应返回 `{"status":"ok"}`。如果根域名已有别的内容，它不受这个 `/api/` 代理影响。

## 维护

- 查看服务：`docker compose ps`
- 查看日志：`docker compose logs -f api`
- 更新版本：在 `backend` 目录运行 `git pull --ff-only origin main && docker compose up -d --build`
- 备份数据库：`docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > littlekitchen-$(date +%F).sql`

图片保存在 Docker 命名卷 `uploads-data` 中，数据库保存在 `postgres-data` 中。服务器 40G 硬盘足够做起步版，但应每周把数据库备份文件复制到你的电脑或 NAS；图片备份将在数据量增长后再加。
