FROM ghcr.io/vevc/ubuntu:25.11.15

USER root

# 1. 安装基础工具 (确保有 pkill 所在的 procps 包)
RUN apt-get update && apt-get install -y \
    supervisor \
    procps \
    wget \
    curl \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# 2. 固化环境变量
ENV SSH_USER=zv
ENV SSH_PASSWORD=105106

# 3. 【核心修复】将别名写进系统全局配置文件 /etc/bash.bashrc
# 这样无论容器重启多少次，新容器一出生就自带这些命令
RUN echo "alias sctl='supervisorctl -c /home/zv/boot/supervisord.conf'" >> /etc/bash.bashrc && \
    echo "alias vpreboot='pkill -9 supervisord'" >> /etc/bash.bashrc && \
    echo "alias sload='supervisorctl -c /home/zv/boot/supervisord.conf reload'" >> /etc/bash.bashrc

# 4. 创建启动脚本 (修复变量解析版)
RUN echo '#!/bin/bash\n\
# 在运行时动态读取环境变量\n\
USER_HOME="/home/${SSH_USER:-zv}"\n\
BOOT_DIR="${USER_HOME}/boot"\n\
\n\
mkdir -p ${BOOT_DIR} /var/run/sshd\n\
\n\
# 使用 \$ 确保变量在运行时解析\n\
id -u ${SSH_USER} &>/dev/null || useradd -m -s /bin/bash ${SSH_USER}\n\
echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd\n\
echo "root:${SSH_PASSWORD}" | chpasswd\n\
\n\
ssh-keygen -A\n\
\n\
cat <<EOF > ${BOOT_DIR}/supervisord.conf\n\
[supervisord]\n\
nodaemon=true\n\
user=root\n\
\n\
[program:sshd]\n\
command=/usr/sbin/sshd -D -p 2233 -o "PermitRootLogin=yes" -o "PasswordAuthentication=yes"\n\
autostart=true\n\
autorestart=true\n\
\n\
[include]\n\
# 这里的路径在 EOF 内部，会自动保留变量值\n\
files = ${BOOT_DIR}/*.conf\n\
EOF\n\
\n\
chmod -R 777 ${USER_HOME}\n\
exec /bin/supervisord -c ${BOOT_DIR}/supervisord.conf' > /entrypoint_custom.sh && chmod +x /entrypoint_custom.sh
