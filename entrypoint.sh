#!/bin/bash
set -e

# 1. 检查并创建自定义用户
# 如果用户不存在则创建
if ! id -u "${USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${USER}"
fi

# 2. 设置用户密码并允许免密 sudo
echo "${USER}:${PWD}" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-custom-user

# 3. 核心要求：将 /home/${USER} 的权限给到该用户
# 确保家目录存在并递归修改所有权
if [ -d "/home/${USER}" ]; then
    chown -R "${USER}:${USER}" "/home/${USER}"
fi

# 4. 设置时区
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezone

# 5. 启动主进程 (Supervisor)
# 使用 exec 确保 supervisor 能够接收到停止信号 (成为 PID 1)
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
