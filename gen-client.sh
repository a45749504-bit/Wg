#!/bin/bash
# Генерация дополнительного WireGuard-клиента
# Использование: /app/gen-client.sh [номер_клиента]

WG_IFACE="wg0"
WG_SUBNET="${WG_SUBNET:-10.200.200}"
WG_DNS="${WG_DNS:-1.1.1.1,8.8.8.8}"
SERVER_PUBLIC_KEY_FILE="/app/creds/server_public_key"

if [ ! -f "$SERVER_PUBLIC_KEY_FILE" ]; then
    echo "ERROR: Ключи сервера не найдены. Сначала запусти основной контейнер."
    exit 1
fi

SERVER_PUBLIC_KEY=$(cat "$SERVER_PUBLIC_KEY_FILE")
CLIENT_NUM="${1:-$(shuf -i 10-250 -n 1)}"
CLIENT_IP="${WG_SUBNET}.${CLIENT_NUM}"
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
PRESHARED_KEY=$(wg genpsk)

# Добавляем пир в работающий WireGuard
wg set ${WG_IFACE} peer "${CLIENT_PUBLIC_KEY}" preshared-key <(echo "$PRESHARED_KEY") allowed-ips "${CLIENT_IP}/32" 2>/dev/null || {
    echo "WARN: Не удалось добавить пир в wg. Возможно, WireGuard не запущен."
}

cat <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = ${WG_DNS}
MTU = 1280

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 127.0.0.1:51820
PersistentKeepalive = 25
EOF
