#!/bin/bash
set -e

# 1. 彻底根治 SSH 认证问题 (针对 PAM: Authentication failure)
# 修正 Ubuntu 22.04 在容器内对 loginuid 的审计限制
if [ -f /etc/pam.d/sshd ]; then
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd
fi

# 确保 SSH 配置强制允许密码登录，覆盖任何潜在的默认限制
mkdir -p /run/sshd
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# 2. 账户处理与密码强化
if ! id -u "${USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${USER}"
fi
# 显式重设一次密码，确保写入 shadow 文件
echo "${USER}:${PWD}" | chpasswd
# 给 root 也设个密码（可选，建议设为一致，方便调试）
echo "root:${PWD}" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-custom-user

# 3. 环境变量与 Alias 优化 (覆盖 root 和 zv)
# 定义一个函数，统一给所有 shell 环境注入 alias
setup_alias() {
    local target_rc=$1
    # 先清理可能存在的旧 alias，防止重复写入
    sed -i '/alias sctl=/d' "$target_rc" 2>/dev/null || true
    echo "alias sctl='sudo supervisorctl'" >> "$target_rc"
    # 确保交互式登录能正确加载 alias
    local target_profile="${target_rc%/*}/.bash_profile"
    echo "[[ -f $target_rc ]] && . $target_rc" > "$target_profile"
}

setup_alias "/root/.bashrc"
setup_alias "/home/${USER}/.bashrc"
chown -R "${USER}:${USER}" "/home/${USER}"

# 4. 最终清理：防止 Supervisor 启动时端口冲突
pkill sshd || true

# 5. 启动
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
