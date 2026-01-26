FROM ghcr.io/vevc/ubuntu:25.11.15

USER root

# 1. 安装基础工具
RUN apt-get update && apt-get install -y \
    supervisor \
    procps \
    wget \
    curl \
    passwd \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# 2. 固化环境变量
ENV SSH_USER=zv
ENV SSH_PASSWORD=105106

# 3. 固化全局别名 (确保每个登录 Shell 都能直接使用 sctl)
RUN echo "alias sctl='supervisorctl -c /home/zv/boot/supervisord.conf'" >> /etc/bash.bashrc && \
    echo "alias vpreboot='pkill -9 supervisord'" >> /etc/bash.bashrc && \
    echo "alias sload='supervisorctl -c /home/zv/boot/supervisord.conf reload'" >> /etc/bash.bashrc

# 4. 创建启动脚本
RUN printf "#!/bin/bash\n\
export USER_HOME=\"/home/\${SSH_USER:-zv}\"\n\
export BOOT_DIR=\"\${USER_HOME}/boot\"\n\
\n\
mkdir -p \"\${BOOT_DIR}\" /var/run/sshd /var/log/supervisor\n\
\n\
id -u \${SSH_USER} &>/dev/null || useradd -m -s /bin/bash \${SSH_USER}\n\
echo \"\${SSH_USER}:\${SSH_PASSWORD}\" | chpasswd\n\
echo \"root:\${SSH_PASSWORD}\" | chpasswd\n\
\n\
ssh-keygen -A\n\
\n\
# 写入 Supervisor 配置\n\
printf \"[supervisord]\nnodaemon=true\nuser=root\nlogfile=/tmp/supervisord.log\n\n[program:sshd]\ncommand=/usr/sbin/sshd -D -p 2233 -o PermitRootLogin=yes -o PasswordAuthentication=yes\nautostart=true\nautorestart=true\n\n[include]\nfiles = \${BOOT_DIR}/*.conf\n\" > \"\${BOOT_DIR}/supervisord.conf\"\n\
\n\
chmod -R 777 \"\${USER_HOME}\"\n\
\n\
exec /bin/supervisord -c \"\${BOOT_DIR}/supervisord.conf\"\n" > /entrypoint_custom.sh && chmod +x /entrypoint_custom.sh

# 5. 设置入口点
ENTRYPOINT ["/bin/bash", "/entrypoint_custom.sh"]
