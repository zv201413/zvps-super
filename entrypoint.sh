#!/usr/bin/env sh
set -e

# --- 1. 设置默认值 (如果环境变量没给，就用 zv/105106) ---
USER_NAME=${SSH_USER:-zv}
USER_PWD=${SSH_PWD:-105106}

echo "👤 当前用户: $USER_NAME"

# --- 2. 动态创建用户 ---
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$USER_NAME" || true
fi

# 修正家目录权限
chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"

# 设置密码与 sudo 权限
echo "root:$USER_PWD" | chpasswd
echo "$USER_NAME:$USER_PWD" | chpasswd
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users
ln -sf /usr/bin/supervisorctl /usr/local/bin/sctl

# --- 3. 处理持久化配置 ---
BOOT_DIR="/home/$USER_NAME/boot"
BOOT_CONF="$BOOT_DIR/supervisord.conf"
TEMPLATE="/usr/local/etc/supervisord.conf.template"

mkdir -p "$BOOT_DIR"

# 如果文件不存在，或者开启了强制更新
if [ ! -f "$BOOT_CONF" ] || [ "$FORCE_UPDATE" = "true" ]; then
    echo "📦 正在初始化/更新持久化配置模板..."
    cp "$TEMPLATE" "$BOOT_CONF"
    
    # 【动态注入】将配置文件里的占位符替换为实际的用户名
    sed -i "s/{SSH_USER}/$USER_NAME/g" "$BOOT_CONF"
    
    chown "$USER_NAME":"$USER_NAME" "$BOOT_CONF"
fi

# 设置 sctl 命令别名，让它自动找对配置文件
echo "alias sctl='supervisorctl -c $BOOT_CONF'" >> /etc/bash.bashrc

# --- 4. 启动 ---
if [ -n "$SSH_CMD" ]; then
    echo "🚀 执行自定义 SSH_CMD: $SSH_CMD"
    exec /bin/sh -c "$SSH_CMD"
else
    echo "✅ 启动 Supervisor (用户: $USER_NAME)..."
    exec /usr/bin/supervisord -n -c "$BOOT_CONF"
fi
