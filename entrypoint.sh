#!/bin/bash
set -e

# 1. SSH 配置优化：既保证安全又保证容器内兼容性
# 允许密码登录
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# 重要：在 Docker 容器内，通常需要开启 UsePAM 才能正确识别 chpasswd 设置的密码
sed -i 's/^#\?UsePAM.*/UsePAM yes/g' /etc/ssh/sshd_config
# 允许 root 登录（如果你需要的话，可选）
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# 2. 账户处理
if ! id -u "${USER}" >/dev/null 2>&1; then
    # 显式指定 UID 和组，防止权限漂移
    useradd -m -s /bin/bash "${USER}"
fi
echo "${USER}:${PWD}" | chpasswd

# 3. 修复目录权限（SSH 登录对家目录权限非常敏感）
chown -R "${USER}:${USER}" /home/${USER}
chmod 755 /home/${USER}

# 4. 环境变量与 Alias
# 注意：SSH 登录后是非交互式 shell，建议写入 .profile 或 .bashrc
echo "alias sctl='sudo supervisorctl'" > /home/${USER}/.bashrc
echo "export USER=${USER}" >> /home/${USER}/.bash_profile
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-custom-user

# 5. 启动
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
