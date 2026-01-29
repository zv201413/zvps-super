#!/bin/bash
set -e

# 1. SSH 授权优化：针对普通用户登录做最简授权
# 确保允许密码登录
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# 针对部分环境，关闭空密码限制和强行开启授权
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM.*/UsePAM no/g' /etc/ssh/sshd_config

# 2. 账户处理
if ! id -u "${USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${USER}"
fi
echo "${USER}:${PWD}" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-custom-user

# 3. 环境变量注入：让 USER 在 SSH 登录后也能直接用 sctl
echo "alias sctl='sudo supervisorctl'" >> /home/${USER}/.bashrc
chown -R "${USER}:${USER}" /home/${USER}

# 4. 启动
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
