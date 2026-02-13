# 🚀 ZVPS-Super 2026 增强版

基于 **Ubuntu** 的智能型容器基础镜像。支持通过环境变量动态接管启动进程，结合 **Supervisor** 实现多服务保活、**全自动配置初始化**与持久化存储。

---
## 🐳 Docker 方式部署指南

你可以通过 Docker 快速部署并运行 **ZVPS-Super**。根据你的实际需求选择以下启动方式。

### 1. ⚡ 极简启动 (仅 SSH + Web 终端)
适用于快速测试，不保存数据，容器销毁后配置丢失。

```bash
docker run -d \
  --name zvps-super \
  -e SSH_PWD="your_password" \
  -p 2222:22 \
  -p 7681:7681 \
  zv201413/zvps-super
```
### 2. 🚀 全功能启动 (持久化 + 监控 + 隧道)

**推荐方案**：适用于生产或长期使用环境。此配置支持流量统计数据的持久化存储，并通过 Cloudflare Tunnel 实现内网穿透。

```bash
docker run -d \
  --name zvps-super \
  -e SSH_USER="root" \
  -e SSH_PWD="your_password" \
  -e GB=true \
  -e CF_TOKEN="your_cloudflare_token" \
  -v /opt/zvps_data:/root \
  -p 2222:22 \
  -p 7681:7681 \
  --restart unless-stopped \
  zv201413/zvps-super
```
### 📝 参数详解 (Configuration)

| 变量/参数 | 示例值 | 类型 | 说明 |
| :--- | :--- | :--- | :--- |
| `-e SSH_PWD` | `yourpassword` | **必填** | 设置 SSH 远程登录密码 |
| `-e SSH_USER` | `root` | 选填 | 默认为 `root`。若修改，请务必同步修改挂载路径 |
| `-e GB` | `true` | 选填 | 是否开启流量监控。开启后可使用 `gb` 指令 |
| `-e CF_TOKEN` | `your_token` | 选填 | 填入后自动开启 Cloudflare Tunnel 远程访问 |
| `-e SSH_CMD` | `""` | 选填 | **留空**：启动 Supervisor 服务管理；**填入**：替代所有服务只执行该命令 |
| `-v /host:/root` | `/data:/root` | **关键** | **宿主机路径 : 容器家目录**。用于持久化保存配置和流量数据 |
| `-p 2222:22` | `2222:22` | 端口 | SSH 访问端口 (宿主机端口:容器内22端口) |
| `-p 7681:7681` | `7681:7681` | 端口 | Web SSH 浏览器访问端口 (可通过浏览器直接操作终端) |

---

> [!TIP]
> **关于 SSH_CMD 的特别说明：**
> 如果你需要容器作为一个单纯的执行环境（例如只运行一个爬虫脚本或临时任务），可以填入命令。否则请保持留空，以确保 SSH 和 Web UI 等后台服务正常启动。




## 🛠️ 各种容器平台部署指南

> [!IMPORTANT]
> **核心原则：** 容器启动时会根据环境变量自动生成配置。请确保在首次部署前完成以下设置。

### 步骤 1：一站式环境配置

#### 1. 设置环境变量
在平台部署时，填写镜像地址后添加环境变量（如 Zeabur Environment Variables）：

| 变量名 | 示例值 | 说明 |
| :--- | :--- | :--- |
| **SSH_USER** | `root` | **建议设为 root** 以获得最高权限和完整功能 |
| **SSH_PWD** | `yourpassword` | SSH 登录密码 |
| **GB** | `true` | **必填**：开启后自动安装 vnstat 并注入 `gb` 快捷指令 |
| **CF_TOKEN** | `your_token` | (可选) 填入则自动激活 Cloudflared 隧道 |
| **SSH_CMD** | `""` | **留空**：启动 Supervisor 管理；**填入**：则只执行该命令并替代管理服务 |

> [!TIP]
> **Cloudflare 配置关键点：**
> 在 Cloudflare Tunnel 控制台添加 Public Hostname 时：
> - **Service Type:** 必须选择 `SSH`
> - **URL:** 必须填写 `localhost:22`

#### 2. 挂载持久化存储 (Storage) ⚠️

> [!CAUTION]
> **重要：挂载路径必须与 SSH_USER 严格一致，否则持久化将失效！**

请根据你的 `SSH_USER` 设置选择对应的挂载路径：
- **若 SSH_USER = `root`**
  挂载路径必须设为：`/root`
- **若 SSH_USER = `zv` (或自定义用户名)**
  挂载路径必须设为：`/home/zv` (或 `/home/你的用户名`)

---

### 步骤 2：基础玩法与流量监控

容器部署完成后，你将获得一个开箱即用的环境：

1. **流量监控指令：`gb`**
   - 只要开启了 `GB=true`，进入终端输入 `gb` 即可查看流量。
   - **输出示例：** `📥 RX: 1024.00 MB (1.00 GB) | 📤 TX: 256.50 MB (0.25 GB)`
   - *注：初次启动需等待约 5 分钟采样，若提示 "Not enough data" 请稍后再试。*

2. **快捷管理 `sctl`**: 
   - 镜像已内置 `sctl` (即 `supervisorctl`)。输入 `sctl` 即可查看所有进程（sshd, ttyd, vnstat等）状态。

3. **Web SSH 访问**: 
   - 访问平台分配的域名（对应容器 7681 端口），即可通过浏览器进入终端，实现免客户端登录。

---

### 步骤 3：进阶配置持久化

镜像启动后会自动在挂载目录下生成相关文件：

- **`init_env.sh`**: 
  - 自动生成的初始化勾子脚本。你可以编辑此文件添加 `apt install` 或自定义 `alias`。
- **`boot/supervisord.conf`**: 
  - **自定义服务**: 编辑此文件可添加 `xray`、`gost` 等进程。
  - **热加载**: 修改后执行 `sctl update` 即可生效，无需重启容器。
- **`vnstat_data/`**: 
  - 自动保存流量统计数据库，确保容器销毁重建后流量记录不清零。

---

## 🔐 远程访问：通过本地 SSH 客户端登录

### 1. ⚡ 推荐：命令行一键秒连 (最简操作)

如果你本地已安装 SSH 客户端（Win10/11 默认自带），只需执行以下整合指令。它会自动在后台拉起隧道并直接发起 SSH 连接：

```dos
:: 替换“你的域名”和“2222”为实际值即可
start /b cloudflared.exe access tcp --hostname 你的域名 --url localhost:2222 & ssh -p 2222 root@127.0.0.1
```
**操作提示：**

1. 第一次连接会询问 "Are you sure you want to continue connecting (yes/no/[fingerprint])?"
2. 请手动输入 **yes** 并回车。
3. 随后看到 "password:" 提示时，输入你在环境变量中设置的 **SSH_PWD** 即可。
   (注意：输入密码时屏幕不会显示任何字符，输完直接按回车即可)

### 2. 第三方客户端登录方法 (FinalShell, Xshell, PuTTY 等)

当上述隧道指令运行后，如果要第三方 SSH 工具中新建连接，可按以下参数填写：

| 配置项          | 填入内容           | 说明                                     |
| :-------------- | :----------------- | :--------------------------------------- |
| **主机 (Host/IP)** | `127.0.0.1`        | **核心**：不要填你的域名，要填本地回环地址 |
| **端口 (Port)** | `2222`             | 必须与你启动隧道指令中的端口一致         |
| **用户名 (User)** | `root`             | 或你在环境变量 SSH_USER 中设置的名字，但不会有root权限     |
| **验证方式** | `密码 (Password)`  | 选择密码登录                             |
| **密码** | `你的 SSH_PWD`     | 你在环境变量中设置的密码                 |

---


## 🏁 流程总结

1. **填变量**：在平台面板设置 `SSH_USER`、`SSH_PWD`、`GB`、`CF_TOKEN`。
2. **挂存储**：根据用户选择挂载到 `/root` 或 `/home/用户名`（**关键：路径须与用户名一致**）。
3. **收工**：部署成功后，使用 `gb` 查流量，使用 `sctl` 管进程。

---

**🤝 鸣谢**
本项目参考了 `vevc/ubuntu` 的设计思路，并针对持久化存储挂载逻辑、vnstat 流量统计自动初始化及双显 `gb` 快捷指令进行了深度定制。
