#!/bin/bash
set -e

# ============================================
# WireGuard + Wstunnel Server for Render.com
# ============================================
# Ожидаемые переменные окружения:
#   PORT                  — предоставляется Render автоматически
#   WSTUNNEL_SECRET       — обязательно задай вручную (мин. 32 символа)
#   CLIENT_PUBLIC_KEY     — публичный ключ клиента WireGuard
#   CLIENT_PUBLIC_KEY_2   — опционально, второй клиент
#   CLIENT_PUBLIC_KEY_3   — опционально, третий клиент
#   PRESHARED_KEY         — опционально, для доп. безопасности
#   WG_PORT               — порт WireGuard (default: 51820)
#   WG_SUBNET             — подсеть (default: 10.200.200.0/24)
#   WG_SERVER_IP          — IP сервера в подсети (default: 10.200.200.1)
#   WG_CLIENT_IP          — IP клиента в подсети (default: 10.200.200.2)
#   DNS_SERVERS           — DNS через запятую (default: 1.1.1.1,8.8.8.8)
# ============================================

# Значения по умолчанию
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.200.200.0/24}"
WG_SERVER_IP="${WG_SERVER_IP:-10.200.200.1}"
WG_CLIENT_IP="${WG_CLIENT_IP:-10.200.200.2}"
DNS_SERVERS="${DNS_SERVERS:-1.1.1.1,8.8.8.8}"

# Проверка обязательных переменных
if [ -z "${WSTUNNEL_SECRET}" ]; then
    echo "❌ ОШИБКА: WSTUNNEL_SECRET не задан!"
    echo "   Задай его в Environment Variables на Render.com"
    echo "   Минимум 32 случайных символа."
    echo ""
    echo "   Пример генерации:"
    echo "   openssl rand -base64 32"
    exit 1
fi

if [ -z "${CLIENT_PUBLIC_KEY}" ]; then
    echo "⚠️  WARNING: CLIENT_PUBLIC_KEY не задан!"
    echo "   Сервер запустится, но клиент не сможет подключиться."
    echo ""
fi

# Генерация ключей сервера (если ещё не сгенерированы)
if [ ! -f /etc/wireguard/privatekey ]; then
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/publickey)

# PresharedKey
if [ -n "${PRESHARED_KEY}" ]; then
    echo "${PRESHARED_KEY}" > /etc/wireguard/presharedkey
elif [ ! -f /etc/wireguard/presharedkey ]; then
    wg genpsk > /etc/wireguard/presharedkey
fi
PSK=$(cat /etc/wireguard/presharedkey)

# Настройка WireGuard интерфейса
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = ${WG_SERVER_IP}/24
ListenPort = ${WG_PORT}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

# Добавляем peer(s)
add_peer() {
    local pubkey="$1"
    local ip="$2"
    if [ -n "$pubkey" ]; then
        cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = ${pubkey}
PresharedKey = ${PSK}
AllowedIPs = ${ip}/32
EOF
    fi
}

add_peer "${CLIENT_PUBLIC_KEY}" "${WG_CLIENT_IP}"
add_peer "${CLIENT_PUBLIC_KEY_2}" "10.200.200.3"
add_peer "${CLIENT_PUBLIC_KEY_3}" "10.200.200.4"

# Включаем IP forwarding
sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1 || true

# Запуск WireGuard
wg-quick up wg0

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        WireGuard + Wstunnel Server запущен                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Server Public Key:  ${SERVER_PUBLIC_KEY}"
echo "║  PresharedKey:       ${PSK}"
echo "║  WireGuard Port:     ${WG_PORT}"
echo "║  Wstunnel Port:      ${PORT:-8080}"
echo "║  Secret Path:        ${WSTUNNEL_SECRET:0:20}..."
echo "║  Server IP:          ${WG_SERVER_IP}"
echo "║  Client IP:          ${WG_CLIENT_IP}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Запуск wstunnel server
exec wstunnel server \
    --restrict-to "localhost:${WG_PORT}" \
    --restrict-http-upgrade-path-prefix "${WSTUNNEL_SECRET}" \
    "wss://0.0.0.0:${PORT:-8080}"
