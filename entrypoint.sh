#!/usr/bin/env sh
set -e

# 1. 基础环境初始化（确保账户永远正确）
# 如果用户不存在则创建，并设置密码为环境变量 SSH_PWD 的值
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$SSH_USER"
fi
echo "$SSH_USER:$SSH_PWD" | chpasswd
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users

# 2. 注入快捷别名 sctl (方便后续管理 Supervisor)
echo "alias sctl='sudo supervisorctl'" >> /root/.bashrc
echo "alias sctl='sudo supervisorctl'" >> "/home/$SSH_USER/.bashrc"

# 3. 核心分流逻辑：
# 如果设置了 SSH_CMD 变量，则将其拆分为参数，替换掉容器默认的 CMD
if [ -n "$SSH_CMD" ]; then
    set -- $SSH_CMD
fi

# 4. 启动最终进程
# 如果没有 SSH_CMD，也没有 Arguments，它将执行 Dockerfile 中 CMD 定义的默认命令
exec "$@"
