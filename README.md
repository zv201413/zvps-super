# 🚀 ZVPS-Super 基地镜像

基于 Ubuntu 的通用型容器基地。支持通过环境变量动态接管启动进程，结合 Supervisor 实现多服务保活与持久化存储。

---

## 🛠️ 拉取镜像后的操作流程

> [!IMPORTANT]
> **注意执行步骤：** 最初一定不要挂载永久化存储位置，也请勿设置 `SSH_CMD`。

### 步骤 1：初次启动（默认模式）

如果你现在刚拉取镜像，请先在平台（Zeabur / Railway 等）仅设置基础环境变量：

* **SSH_USER**: 你的用户名
* **SSH_PWD**: 你的密码

---

### 步骤 2：准备持久化“大脑”

通过平台自带的 Web 终端连入容器，手动创建 `boot` 目录：

```bash
mkdir -p /home/zv/boot
随后将系统默认的 Supervisor 配置拷贝出来作为模板（或者直接参考步骤 3 手动创建）：

Bash
sudo cp /etc/supervisor/supervisord.conf /home/zv/boot/supervisord.conf
```

### 步骤 3：配置持久化文件

编辑 /home/zv/boot/supervisord.conf，确保包含基础服务：

```Ini, TOML
[supervisord]
nodaemon=true
user=root

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true

[program:ttyd]
command=/usr/local/bin/ttyd -W bash
autostart=true
autorestart=true
```

### 步骤 4：启用基地模式

挂载存储：将持久化卷挂载到 /home/zv/boot。

设置启动变量：添加环境变量 ```SSH_CMD = /usr/bin/supervisord -n -c /home/zv/boot/supervisord.conf。```

<img width="1143" height="564" alt="image" src="https://github.com/user-attachments/assets/1bc77532-93f6-4f81-b8e1-f268004cd485" />

[!TIP] 如果平台支持且你想用 Arguments，可填写：``` ["supervisord", "-n", "-c", "/home/zv/boot/supervisord.conf"]```

<img width="606" height="227" alt="image" src="https://github.com/user-attachments/assets/3c1f054e-2aa4-415e-9baa-398ff893e911" />

重启容器：完成最后部署。

💡 写在最后
Web 终端支持：本镜像集成 ttyd。当你使用的平台不支持 SSH 或者你习惯用 Web 登录，请添加 HTTP 类型的网络端口为 7681 的外部可访问链接，生成后点击链接即可登录。 <img width="1119" height="273" alt="image" src="https://github.com/user-attachments/assets/f17318c0-7965-489e-91f2-9a6bb82d70e3" />

用户名适配：以上流程演示中使用了默认的 zv 用户名，请根据你个人在环境变量中设置的 SSH_USER 进行相应路径修改。

🤝 鸣谢
本项目参考了 vevc/ubuntu 大佬的设计思路，并针对持久化、supervisor启动与快捷操作、ttyd集成等场景进行了优化与补充。
