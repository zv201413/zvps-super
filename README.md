# ZVPS-Super

基于 Ubuntu 22.04 的智能型增强版容器镜像，集成 SSH、Web 终端、流量监控及自动化保活功能。

## 🌟 核心特色

- ✅ **全自动化配置**：启动时根据环境变量动态生成 Supervisor 与服务配置。
- ✅ **持久化支持**：支持用户家目录、配置及流量数据的持久化挂载。
- ✅ **多维保活**：内置 `kpal` 模块，支持自定义参数的定时保活请求。
- ✅ **流量监控**：内置 `vnstat` 并提供 `gb` 快捷指令查看流量。
- ✅ **智能更新**：采用 Fingerprint 指纹识别技术，环境变量变更自动重构配置。
- ⚠️ **挂载校验**：挂载路径必须与 `SSH_USER` 保持严格一致，否则持久化失效。

---

## 前期准备

### 获取 Cloudflare Tunnel Token
1. 在 Cloudflare Zero Trust 控制台创建一个 Tunnel。
2. 记录 Token 用于环境变量配置。

---

## 使用方法

### 第一步：启动容器 (Docker 示例)
```bash
docker run -d \
  --name zvps-super \
  -e SSH_USER="zv" \
  -e SSH_PWD="your_password" \
  -e KPAL="240+60:https://your-url" \
  -e CF_TOKEN="your_token" \
  -v /opt/zvps_data:/home/zv \
  -p 2222:22 \
  zv201413/zvps-super
```

### 第二步：配置环境变量

| 变量名称 | 必填 | 说明 |
|:---|:---:|:---|
| SSH_PWD | ✅ | SSH 登录密码 |
| KPAL | ⚠️ | 保活配置 (格式: `随机范围+偏移量:URL`) |
| CF_TOKEN | ⚠️ | 开启 Cloudflare Tunnel |
| GB | - | 设置为 `true` 开启流量统计 |
| TTYD_P1 | - | 自定义 Web 终端 1 (格式: `端口:用户:密码`) |

---

## 运行逻辑

| 场景 | 行为 |
|:---|:---|
| 首次启动 | 自动创建用户、初始化家目录、生成 `init_env.sh` |
| 环境变量变更 | 识别 Fingerprint 差异，自动重写 `supervisord.conf` |
| 保活周期 | 每 5 分钟由 `kpal` 触发，带随机延迟访问指定 URL |
| 终端管理 | 提供 `sctl` (supervisorctl) 快捷管理各进程状态 |

---

## 快捷指令说明

| 指令 | 说明 | 示例输出 |
|:---:|:---|:---|
| `gb` | 查看流量统计 | `📥 RX: 1.00 GB | 📤 TX: 0.25 GB` |
| `sctl` | 管理服务进程 | `kpal RUNNING pid 123, uptime 0:05:00` |

---

## 常见问题

### Q1: 为什么修改了环境变量配置没变？
**A**: 容器具备指纹识别功能，如果配置未自动更新，可设置 `FORCE_UPDATE=true` 强制刷新。

### Q2: 如何查看保活状态？
**A**: 执行 `sctl status kpal` 查看进程，或查看 `/tmp/keepalive.log` 日志。

---

## 🌟 特别鸣谢

感谢 `vevc/ubuntu` 提供的原始设计参考。
