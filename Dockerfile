FROM ubuntu:22.04

# 基础环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    SSH_USER=zv \
    SSH_PWD=105106

# 安装基础包
RUN apt-get update && apt-get install -y \
    openssh-server supervisor curl wget sudo ca-certificates \
    tzdata vim net-tools unzip iputils-ping telnet git iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 安装 cloudflared 和 ttyd
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared.deb \
    && rm cloudflared.deb \
    && curl -L https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# 准备 SSH 环境
RUN mkdir -p /run/sshd && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- 生成满血版模板 (echo 方案，避开所有解析错误) ---
RUN mkdir -p /usr/local/etc && \
    echo "[unix_http_server]" > /usr/local/etc/supervisord.conf.template && \
    echo "file=/var/run/supervisor.sock" >> /usr/local/etc/supervisord.conf.template && \
    echo "chmod=0700" >> /usr/local/etc/supervisord.conf.template && \
    echo "" >> /usr/local/etc/supervisord.conf.template && \
    echo "[supervisord]" >> /usr/local/etc/supervisord.conf.template && \
    echo "nodaemon=true" >> /usr/local/etc/supervisord.conf.template && \
    echo "user=root" >> /usr/local/etc/supervisord.conf.template && \
    echo "logfile=/var/log/supervisor/supervisord.log" >> /usr/local/etc/supervisord.conf.template && \
    echo "pidfile=/var/run/supervisord.pid" >> /usr/local/etc/supervisord.conf.template && \
    echo "" >> /usr/local/etc/supervisord.conf.template && \
    echo "[rpcinterface:supervisor]" >> /usr/local/etc/supervisord.conf.template && \
    echo "supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface" >> /usr/local/etc/supervisord.conf.template && \
    echo "" >> /usr/local/etc/supervisord.conf.template && \
    echo "[supervisorctl]" >> /usr/local/etc/supervisord.conf.template && \
    echo "serverurl=unix:///var/run/supervisor.sock" >> /usr/local/etc/supervisord.conf.template && \
    echo "" >> /usr/local/etc/supervisord.conf.template && \
    echo "[program:sshd]" >> /usr/local/etc/supervisord.conf.template && \
    echo "command=/usr/sbin/sshd -D" >> /usr/local/etc/supervisord.conf.template && \
    echo "autostart=true" >> /usr/local/etc/supervisord.conf.template && \
    echo "autorestart=true" >> /usr/local/etc/supervisord.conf.template && \
    echo "" >> /usr/local/etc/supervisord.conf.template && \
    echo "[program:ttyd]" >> /usr/local/etc/supervisord.conf.template && \
    echo "command=/usr/local/bin/ttyd -W bash" >> /usr/local/etc/supervisord.conf.template && \
    echo "autostart=true" >> /usr/local/etc/supervisord.conf.template && \
    echo "autore
