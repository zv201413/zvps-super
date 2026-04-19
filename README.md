# 🚀 ZVPS-Super 2026 增强版

基于 **Ubuntu** 的智能型容器基础镜像。支持通过环境变量动态接管启动进程，结合 **Supervisor** 实现多服务保活、**全自动配置初始化**与持久化存储。

---

## 🛠️ 部署方式 (Deployment Methods)

你可以根据使用环境选择以下两种并列的部署方式：

### A. 🐳 Docker 命令行部署 (Docker CLI)
适用于本地服务器或具有 Docker 访问权限的 VPS。

#### 1. ⚡ 极简启动 (仅 SSH + Web 终端)
```bash
docker run -d \
  --name zvps-super \
  -e SSH_PWD="your_password" \
  -p 2222:22 \
  -p 7681:7681 \
  zv201413/zvps-super
```

#### 2. 🚀 全功能启动 (持久化 + 隧道 + 保活)
```bash
docker run -d \
  --name zvps-super \
  -e SSH_USER="zv" \
  -e SSH_PWD="your_password" \
  -e GB=true \
  -e KPAL="240+60:https://your-monitor-url" \
  -e CF_TOKEN="your_cloudflare_token" \
  -e TTYD_P1="7681:admin:your_password" \
  -v /opt/zvps_data:/home/zv \
  -p 2222:22 \
  -p 7681:7681 \
  --restart unless-stopped \
  zv201413/zvps-super
```

---

### B. ☁️ 容器平台环境变量部署 (Cloud Platforms)
适用于 Zeabur, Railway, Render 等无直接 Docker 访问权限的平台。

#### 1. 一站式环境配置
在平台面板添加以下环境变量：

| 变量名 | 示例值 | 说明 |
| :--- | :--- | :--- |
| **SSH_USER** | `zv` | SSH 用户名（默认获得最高权限） |
| **SSH_PWD** | `105106` | SSH 登录密码 |
| **KPAL** | `240+60:URL` | **(新)** 保活配置。格式：`随机范围+偏移量:目标URL` |
| **GB** | `true` | (可选) 开启后自动安装 vnstat 流量统计 |
| **CF_TOKEN** | `your_token` | (可选) 填入则自动激活 Cloudflared 隧道 |
| **TTYD_P1** | `7681:admin:123` | (可选) 第一个 Web 终端。格式：`端口:用户:密码` |
| **TTYD_P2** | `80:admin:123` | (可选) 第二个 Web 终端（用于 CF Tunnel 整合） |

#### 2. 挂载持久化存储 (Storage) ⚠️
**重要：挂载路径必须与 SSH_USER 严格一致！**
- 若 `SSH_USER` = `root`：挂载到 `/root`
- 若 `SSH_USER` = `zv`：挂载到 `/home/zv`

---

## 📝 参数详解与进阶配置

### 📡 智能保活机制 (KPAL)
本项目集成了基于 **Supercronic** 的动态保活功能（服务名：`kpal`）。

*   **变量格式**：`KPAL=随机范围+偏移量:URL`
*   **示例**：`KPAL=240+60:https://example.com/status`
*   **逻辑**：每 5 分钟执行一次，执行前会随机等待 `RANDOM % 240 + 60` 秒。

### 📡 自定义 Web 终端 (ttyd)
设置 `TTYD_P1` 或 `TTYD_P2` 环境变量即可自定义端口和密码。
*   **格式**: `端口:用户名:密码`（密码可省略）
*   **安全提示**: 建议始终设置密码以保护终端安全。

### 📡 配合 Cloudflare Tunnel 使用
设置 `TTYD_P2=80:用户名:密码` 配合 `CF_TOKEN` 使用，可实现 80 端口直接穿透。
*   **CF 控制台配置**：Public Hostname 选 `HTTP`，URL 填 `localhost:80`。

---

## 🛠️ 运维与管理

1.  **流量监控 `gb`**: 开启 `GB=true` 后，在终端输入 `gb` 即可查看双显流量统计。
2.  **进程管理 `sctl`**: 内置 `sctl` (supervisorctl)，可随时查看或重启服务：
    ```bash
    sctl status        # 查看所有进程
    sctl restart kpal  # 重启保活模块
    ```
3.  **配置持久化**: 镜像启动后会在挂载目录下生成 `init_env.sh` (初始化脚本) 和 `boot/supervisord.conf` (服务配置)。修改后执行 `sctl update` 即可。

---

## 🏁 流程总结
1. **选方法**：使用 Docker 命令行或平台环境变量面板。
2. **设变量**：配置 SSH、KPAL、CF 等核心变量。
3. **挂存储**：确保挂载路径与用户名一致。
4. **收工**：部署成功后，使用 `gb` 查流量，使用 `sctl` 管进程。

---

**🤝 鸣谢**
本项目参考了 `vevc/ubuntu` 的设计思路，并针对持久化挂载、流量统计、灵活保活机制进行了深度定制。
