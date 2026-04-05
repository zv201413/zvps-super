FROM ubuntu:22.04

# 1. 基础环境设置 [cite: 1]
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    SSH_USER=zv \
    SSH_PWD=105106

# 2. 安装必要软件包 [cite: 1]
RUN apt-get update && apt-get install -y \
    openssh-server supervisor curl wget sudo ca-certificates \
    tzdata vim net-tools unzip iputils-ping telnet git iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 3. 安装工具 (cloudflared & ttyd) [cite: 1]
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared.deb \
    && rm cloudflared.deb \
    && curl -L https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd 

# 4. 写入集成版保活脚本 (使用 E_http 变量)
RUN cat <<'EOF' > /usr/local/bin/keepalive.sh
#!/bin/bash
# 如果环境变量未设置，脚本直接退出
if [ -z "$E_http" ]; then
    echo "Keepalive variable E_http is not set. Exiting..."
    exit 0
fi

echo "Keepalive daemon started. Target: $E_http"

while true; do
    # 随机休眠 120-300 秒防止平台检测
    sleep $((RANDOM % 180 + 120))
    
    # 执行请求并记录简要日志
    status=$(curl -o /dev/null -s -w "%{http_code}" "$E_http/status")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Status: $status" >> /tmp/keepalive.log
    
    # 自动清理日志，只保留最后 50 行
    if [ $(wc -l < /tmp/keepalive.log) -gt 50 ]; then
        sed -i '1,25d' /tmp/keepalive.log
    fi
done
EOF
RUN chmod +x /usr/local/bin/keepalive.sh

# 5. SSH 环境预处理 [cite: 1]
RUN mkdir -p /run/sshd && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 6. 配置文件与脚本处理 [cite: 1]
RUN mkdir -p /usr/local/etc
COPY supervisord.conf /usr/local/etc/supervisord.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN rm -f /etc/supervisor/supervisord.conf

USER root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
