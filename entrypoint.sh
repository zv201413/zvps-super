#!/usr/bin/env sh
set -e

# 1. 初始化用户与强行修正挂载目录权限
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$SSH_USER" || true
fi

# 核心：无论存储卷以前是谁的，进来先夺取所有权
echo "正在修正 /home/$SSH_USER 权限..."
chown -R "$SSH_USER":"$SSH_USER" /home/"$SSH_USER"

# 密码与 sudo 权限
echo "root:$SSH_PWD" | chpasswd
echo "$SSH_USER:$SSH_PWD" | chpasswd
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users
ln -sf /usr/bin/supervisorctl /usr/local/bin/sctl

# 2. 持久化同步逻辑
BOOT_DIR="/home/$SSH_USER/boot"
BOOT_CONF="$BOOT_DIR/supervisord.conf"
TEMPLATE="/usr/local/etc/supervisord.conf.template"

mkdir -p "$BOOT_DIR"

# 只有当存储卷里没有配置时，才从镜像模板同步
if [ ! -f "$BOOT_CONF" ]; then
    echo "📦 存储卷为空，正在初始化出厂配置..."
    cp "$TEMPLATE" "$BOOT_CONF"
    chown "$SSH_USER":"$SSH_USER" "$BOOT_CONF"
fi

# 3. 确定最终配置文件并清理 PID
FINAL_CONF="$BOOT_CONF"
rm -f /var/run/supervisord.pid /var/run/supervisor.sock /tmp/supervisor.sock

# 4. 启动逻辑
if [ -n "$SSH_CMD" ]; then
    echo "🚀 执行 SSH_CMD: $SSH_CMD"
    exec /bin/sh -c "$SSH_CMD"
else
    echo "✅ 按照持久化配置启动 Supervisor..."
    exec /usr/bin/supervisord -n -c "$FINAL_CONF"
fi
