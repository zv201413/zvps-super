set -e

# --- 1. 设置默认值 (根据 SSH_USER 动态调整 HOME) ---
USER_NAME=${SSH_USER:-zv}
USER_PWD=${SSH_PWD:-105106}

echo "👤 当前用户: $USER_NAME"

# 【新增逻辑：根据用户精确分流工作目录】
if [ "$USER_NAME" = "root" ]; then
    TARGET_HOME="/root"
    echo "⚠️ 模式：ROOT 挂载模式 | 路径：$TARGET_HOME"
else
    TARGET_HOME="/home/$USER_NAME"
    echo "🏠 模式：普通用户模式 | 路径：$TARGET_HOME"
fi

# --- 2. 动态创建用户 (仅当不是 root 时) ---
if [ "$USER_NAME" != "root" ]; then
    if ! id -u "$USER_NAME" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$USER_NAME" || true
    fi
    # 只有目录存在时才 chown，防止报错
    [ -d "$TARGET_HOME" ] && chown -R "$USER_NAME":"$USER_NAME" "$TARGET_HOME"
fi

echo "root:$USER_PWD" | chpasswd
[ "$USER_NAME" != "root" ] && echo "$USER_NAME:$USER_PWD" | chpasswd

echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users
ln -sf /usr/bin/supervisorctl /usr/local/bin/sctl

# --- 3. 处理持久化配置 (使用动态 TARGET_HOME) ---
BOOT_DIR="$TARGET_HOME/boot"
BOOT_CONF="$BOOT_DIR/supervisord.conf"
TEMPLATE="/usr/local/etc/supervisord.conf.template"

mkdir -p "$BOOT_DIR"

# 【后期 DIY 脚本执行】
# 如果你在永久化目录放了 init_env.sh (装 vnstat, 加 gb)，这里会自动执行
if [ -f "$TARGET_HOME/init_env.sh" ]; then
    echo "🚀 运行后期 DIY 初始化..."
    sh "$TARGET_HOME/init_env.sh"
fi

if [ ! -f "$BOOT_CONF" ] || [ "$FORCE_UPDATE" = "true" ]; then
    echo "📦 正在初始化/更新持久化配置模板..."
    cp "$TEMPLATE" "$BOOT_CONF"
    sed -i "s/{SSH_USER}/$USER_NAME/g" "$BOOT_CONF"
    # 修复权限
    [ -d "$TARGET_HOME" ] && chown -R "$USER_NAME":"$USER_NAME" "$BOOT_DIR"
fi

# --- 【CF_TOKEN 判断逻辑】 ---
if [ -z "$CF_TOKEN" ]; then
    echo "⚠️ 未发现 CF_TOKEN，正在配置中禁用 Cloudflared..."
    sed -i '/\[program:cloudflared\]/,/stdout_logfile/s/^/;/ ' "$BOOT_CONF"
else
    echo "☁️ 发现 CF_TOKEN，配置已激活."
    sed -i '/\[program:cloudflared\]/,/stdout_logfile/s/^;//' "$BOOT_CONF"
fi
# ----------------------------------------------

# 设置 sctl 命令别名 (指向动态生成的 BOOT_CONF)
echo "alias sctl='supervisorctl -c $BOOT_CONF'" >> /etc/bash.bashrc

# --- 4. 启动 ---
# 变量重命名逻辑 (遵循 [2026-02-02] 指令)
export SSH_CMD="${SSH_CMD:-$START_CMD}"

if [ -n "$SSH_CMD" ]; then
    echo "🚀 执行自定义 SSH_CMD: $SSH_CMD"
    exec /bin/sh -c "$SSH_CMD"
else
    echo "✅ 启动 Supervisor (用户: $USER_NAME)..."
    exec /usr/bin/supervisord -n -c "$BOOT_CONF"
fi
