#!/usr/bin/env sh
set -e

# 1. 基础环境与用户初始化
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$SSH_USER"
fi

# 同步密码（使用 SSH_PWD 环境变量）
echo "root:$SSH_PWD" | chpasswd
echo "$SSH_USER:$SSH_PWD" | chpasswd
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users

# 2. 注入全局快捷命令 sctl (软链接方案)
ln -sf /usr/bin/supervisorctl /usr/local/bin/sctl

# 3. 持久化初始化逻辑
BOOT_CONF="/home/zv/boot/supervisord.conf"
TEMPLATE="/usr/local/etc/supervisord.conf.template"

# 只有当持久化文件不存在时，才执行拷贝初始化
if [ ! -f "$BOOT_CONF" ] && [ -f "$TEMPLATE" ]; then
    echo "检测到持久化卷为空，正在初始化配置..."
    mkdir -p /home/zv/boot
    cp "$TEMPLATE" "$BOOT_CONF"
fi

# 确定最终使用的配置文件路径
FINAL_CONF="/etc/supervisor/supervisord.conf"
[ -f "$BOOT_CONF" ] && FINAL_CONF="$BOOT_CONF"

# 4. 动态 Cloudflare 探测
if [ -z "$CF_TOKEN" ] && [ -f "$FINAL_CONF" ]; then
    echo "未设置 CF_TOKEN，自动在配置中屏蔽 cloudflare 进程..."
    # 仅在内存/当前配置中注释掉相关行，不破坏文件结构
    sed -i '/\[program:cloudflare\]/s/^/;/' "$FINAL_CONF"
    sed -i '/command=cloudflared/s/^/;/' "$FINAL_CONF"
fi

# 5. 启动分流
if [ -n "$SSH_CMD" ]; then
    echo "执行自定义启动命令: $SSH_CMD"
    exec /bin/sh -c "$SSH_CMD"
else
    echo "按默认配置启动 Supervisord..."
    exec /usr/bin/supervisord -n -c "$FINAL_CONF"
fi
