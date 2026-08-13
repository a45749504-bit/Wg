FROM alpine:3.20

RUN apk add --no-cache     wireguard-tools     wireguard-go     iptables     ip6tables     curl     bash     openssl     qrencode     libqrencode-tools     iproute2     ca-certificates     microsocks     libcap     socat

# ============================================
# WSTunnel: вариант 1 — автоматическое скачивание
# ============================================
ARG WSTUNNEL_VERSION=10.1.9
RUN arch=$(uname -m) &&     case "$arch" in         x86_64) WSTUNNEL_ARCH="x86_64-unknown-linux-musl" ;;         aarch64) WSTUNNEL_ARCH="aarch64-unknown-linux-musl" ;;         *) echo "Unsupported arch: $arch"; exit 1 ;;     esac &&     curl -fsSL -o /tmp/wstunnel.tar.gz     "https://github.com/erebe/wstunnel/releases/download/v${WSTUNNEL_VERSION}/wstunnel_${WSTUNNEL_VERSION}_${WSTUNNEL_ARCH}.tar.gz" &&     tar -xzf /tmp/wstunnel.tar.gz -C /usr/local/bin wstunnel &&     chmod +x /usr/local/bin/wstunnel &&     rm -f /tmp/wstunnel.tar.gz

# ============================================
# WSTunnel: вариант 2 — ручное копирование
# Если хочешь сам скачать wstunnel — закомментируй RUN выше
# и раскомментируй строки ниже. Положи файл "wstunnel" рядом с Dockerfile.
# COPY wstunnel /usr/local/bin/wstunnel
# RUN chmod +x /usr/local/bin/wstunnel
# ============================================

RUN mkdir -p /etc/wireguard /app/config /app/creds

COPY entrypoint.sh /app/entrypoint.sh
COPY gen-client.sh /app/gen-client.sh
RUN chmod +x /app/entrypoint.sh /app/gen-client.sh

EXPOSE 51820/udp

ENV MODE=auto
ENV WG_SUBNET=10.200.200
ENV WG_DNS=1.1.1.1,8.8.8.8
ENV WG_PORT=51820
ENV SOCKS5_PORT=1080
ENV CLIENTS_COUNT=1

ENTRYPOINT ["/app/entrypoint.sh"]
