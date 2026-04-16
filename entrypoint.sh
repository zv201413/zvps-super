#!/usr/bin/env sh
set -e

# --- 1. 设置默认值 ---
USER_NAME=${SSH_USER:-zv}
USER_PWD=${SSH_PWD:-105106}

echo "👤 当前用户: $USER_NAME"

# 【精确路径分流】
if [ "$USER_NAME" = "root" ]; then
    TARGET_HOME="/root"
    echo "⚠️ 模式：ROOT 挂载模式 | 路径：$TARGET_HOME"
else
    TARGET_HOME="/home/$USER_NAME"
    echo "🏠 模式：普通用户模式 | 路径：$TARGET_HOME"
fi

# --- 2. 动态创建用户 ---
if [ "$USER_NAME" != "root" ]; then
    if ! id -u "$USER_NAME" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$USER_NAME" || true
    fi
    [ -d "$TARGET_HOME" ] && chown -R "$USER_NAME":"$USER_NAME" "$TARGET_HOME"
fi

echo "root:$USER_PWD" | chpasswd
[ "$USER_NAME" != "root" ] && echo "$USER_NAME:$USER_PWD" | chpasswd
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users
ln -sf /usr/bin/supervisorctl /usr/local/bin/sctl

# --- 3. 自动化生成 init_env.sh (当 GB 变量开启且脚本不存在时) ---
if [ -n "$GB" ] && [ ! -f "$TARGET_HOME/init_env.sh" ]; then
    echo "📊 检测到 GB 变量，正在自动生成流量统计配置..."
    cat << 'EOF' > "$TARGET_HOME/init_env.sh"
#!/bin/sh
# 1. 安装 vnstat
echo "📥 正在安装 vnstat..."
apt-get update && apt-get install -y vnstat

# 2. 数据库永久化 (迁移至挂载目录下的 vnstat_data)
# 自动检测当前用户家目录
MY_HOME=$(eval echo ~$USER)
mkdir -p "$MY_HOME/vnstat_data"
if [ -d "/var/lib/vnstat" ] && [ ! -L "/var/lib/vnstat" ]; then
    rm -rf /var/lib/vnstat
    ln -s "$MY_HOME/vnstat_data" /var/lib/vnstat
    echo "🔗 vnstat 数据库已建立永久化链接"
fi

# 3. 启动服务
/etc/init.d/vnstat start 2>/dev/null || vnstatd -d

# 4. 注入 gb 快捷指令 (MB/GB 双显版)
# 使用 printf 格式化数字，保留两位小数
BASH_FILE="$MY_HOME/.bashrc"
GB_ALIAS="alias gb='cat /proc/net/dev | grep eth0 | awk \"{print \\\"📥 RX: \\\" sprintf(\\\"%.2f\\\", \$2/1024/1024) \\\" MB (\\\" sprintf(\\\"%.2f\\\", \$2/1024/1024/1024) \\\" GB) | 📤 TX: \\\" sprintf(\\\"%.2f\\\", \$10/1024/1024) \\\" MB (\\\" sprintf(\\\"%.2f\\\", \$10/1024/1024/1024) \\\" GB)\\\"}\"'"
grep -q "alias gb=" "$BASH_FILE" || echo "$GB_ALIAS" >> "$BASH_FILE"
echo "✅ gb 快捷指令已注入 $BASH_FILE"
EOF
    chmod +x "$TARGET_HOME/init_env.sh"
    chown "$USER_NAME":"$USER_NAME" "$TARGET_HOME/init_env.sh"
fi

# --- 4. TTYD 配置解析 ---
# 格式: TTYD_P1=端口:用户名:密码 (端口默认7681，密码可省略)
# 向后兼容: TTYD_P1 未设置时使用 TTYD/TTYD_PORT

parse_ttyd() {
    local var="$1"
    local default_port="$2"
    local result
    
    if [ -n "$(eval echo \${$var})" ]; then
        # 有设置 TTYD_P1 或 TTYD_P2
        local val=$(eval echo \${$var})
        local port=$(echo "$val" | cut -d: -f1)
        local user=$(echo "$val" | cut -d: -f2)
        local pass=$(echo "$val" | cut -d: -f3)
        
        if [ -n "$port" ] && [ "$port" != "$val" ]; then
            # 有端口格式: 端口:user:pass
            result="PORT:$port"
            [ -n "$user" ] && [ -n "$pass" ] && result="$result AUTH:-c $user:$pass"
        elif [ -n "$port" ]; then
            # 只有端口: 端口
            result="PORT:$port"
        else
            result="PORT:$default_port"
        fi
    else
        # 回退到旧变量
        if [ "$var" = "TTYD_P1" ]; then
            [ -n "$TTYD" ] && result="AUTH:-c $TTYD"
            result="${result:-PORT:$default_port}"
        else
            result="PORT:$default_port"
        fi
    fi
    echo "$result"
}

# 解析 TTYD_P1
if [ -n "$TTYD_P1" ]; then
    P1_PORT=$(echo "$TTYD_P1" | cut -d: -f1)
    P1_USER=$(echo "$TTYD_P1" | cut -d: -f2)
    P1_PASS=$(echo "$TTYD_P1" | cut -d: -f3)
    # 如果只有端口没有密码
    if [ -n "$P1_PORT" ] && [ "$P1_PORT" != "$TTYD_P1" ] && [ -z "$P1_USER" ]; then
        P1_PORT=$(echo "$TTYD_P1" | cut -d: -f1)
        P1_AUTH=""
    elif [ -n "$P1_USER" ] && [ -n "$P1_PASS" ]; then
        P1_AUTH="-c $P1_USER:$P1_PASS"
    else
        P1_AUTH=""
    fi
    # 检查端口是否为数字或空
    if ! echo "$P1_PORT" | grep -qE '^[0-9]+$'; then
        P1_PORT="7681"
    fi
else
    # 向后兼容旧变量
    P1_PORT=${TTYD_PORT:-7681}
    if [ -n "$TTYD" ]; then
        P1_AUTH="-c $TTYD"
    else
        P1_AUTH=""
    fi
fi

# 解析 TTYD_P2
if [ -n "$TTYD_P2" ]; then
    P2_PORT=$(echo "$TTYD_P2" | cut -d: -f1)
    P2_USER=$(echo "$TTYD_P2" | cut -d: -f2)
    P2_PASS=$(echo "$TTYD_P2" | cut -d: -f3)
    if [ -n "$P2_USER" ] && [ -n "$P2_PASS" ]; then
        P2_AUTH="-c $P2_USER:$P2_PASS"
    else
        P2_AUTH=""
    fi
    if ! echo "$P2_PORT" | grep -qE '^[0-9]+$'; then
        P2_PORT=""
        P2_AUTH=""
    fi
else
    P2_PORT=""
    P2_AUTH=""
fi

# 生成指纹
FINGERPRINT="USER:$USER_NAME|P1:$P1_PORT|P2:${P2_PORT:-none}|CF:${CF_TOKEN:-none}"

BOOT_DIR="$TARGET_HOME/boot"
STATE_FILE="$BOOT_DIR/.config_state"
BOOT_CONF="$BOOT_DIR/supervisord.conf"
TEMPLATE="/usr/local/etc/supervisord.conf.template"

mkdir -p "$BOOT_DIR"

OLD_FINGERPRINT=$(cat "$STATE_FILE" 2>/dev/null || echo "")

if [ -f "$TARGET_HOME/init_env.sh" ]; then
	sh "$TARGET_HOME/init_env.sh"
fi

if [ ! -f "$BOOT_CONF" ] || [ "$FINGERPRINT" != "$OLD_FINGERPRINT" ] || [ "$FORCE_UPDATE" = "true" ]; then
	echo "🔄 检测到配置变更正在同步..."
	rm -f "$BOOT_CONF"
	cp "$TEMPLATE" "$BOOT_CONF"
	sed -i "s/{SSH_USER}/$USER_NAME/g" "$BOOT_CONF"

	sed -i "s/{TTYD_P1_PORT}/$P1_PORT/g" "$BOOT_CONF"
	sed -i "s/{TTYD_P1_AUTH}/$P1_AUTH/g" "$BOOT_CONF"

	if [ -n "$P2_PORT" ]; then
		sed -i 's/^autostart=false/autostart=true/' "$BOOT_CONF"
		sed -i "s/{TTYD_P2_PORT}/$P2_PORT/g" "$BOOT_CONF"
		sed -i "s/{TTYD_P2_AUTH}/$P2_AUTH/g" "$BOOT_CONF"
	else
		sed -i '/\[program:ttyd2\]/,/autostart/s/^/;/' "$BOOT_CONF"
	fi

	if [ -z "$CF_TOKEN" ]; then
		sed -i '/\[program:cloudflared\]/,/stdout_logfile/s/^/;/' "$BOOT_CONF"
	else
		sed -i '/\[program:cloudflared\]/,/stdout_logfile/s/^;//' "$BOOT_CONF"
	fi

	echo "$FINGERPRINT" > "$STATE_FILE"
	[ -d "$TARGET_HOME" ] && chown -R "$USER_NAME":"$USER_NAME" "$BOOT_DIR"
else
	echo "😴 配置未变更直接启动"
fi

echo "alias sctl='supervisorctl -c $BOOT_CONF'" >> /etc/bash.bashrc

# --- 6. 启动控制 ---
# 如果定义了 SSH_CMD，它将接管容器进程（Supervisor 将不启动）
if [ -n "$SSH_CMD" ]; then
    echo "🚀 执行自定义 SSH_CMD: $SSH_CMD"
    exec /bin/sh -c "$SSH_CMD"
else
    echo "✅ 启动 Supervisor (配置: $BOOT_CONF)..."
    exec /usr/bin/supervisord -n -c "$BOOT_CONF"
fi
