#!/bin/bash
set -e

# ============================================================
# WireGuard + WSTunnel для Render.com
# Автоопределение режима: wireguard / socks5
# ============================================================

WG_IFACE="wg0"
WG_PORT="${WG_PORT:-51820}"
SOCKS5_PORT="${SOCKS5_PORT:-1080}"
WG_SUBNET="${WG_SUBNET:-10.200.200}"
WG_DNS="${WG_DNS:-1.1.1.1,8.8.8.8}"
CLIENTS_COUNT="${CLIENTS_COUNT:-1}"
MODE="${MODE:-auto}"

# Render выдаёт свой PORT — WSTunnel должен слушать именно на нём
if [ -z "$PORT" ]; then
    echo "ERROR: Переменная PORT не задана. На Render она назначается автоматически."
    echo "Для локального запуска укажите: -e PORT=8080"
    exit 1
fi
WSTUNNEL_PORT="$PORT"

echo "========================================"
echo "  WireGuard + WSTunnel Server"
echo "========================================"
echo "Render PORT (WSTunnel): $WSTUNNEL_PORT"
echo "WG_PORT (internal):      $WG_PORT"
echo "SOCKS5_PORT (fallback):  $SOCKS5_PORT"
echo "MODE:                    $MODE"
echo "CLIENTS:                 $CLIENTS_COUNT"
echo ""

# --- Проверяем, есть ли CAP_NET_ADMIN ---
HAS_NET_ADMIN=false
if capsh --print 2>/dev/null | grep -q "cap_net_admin"; then
    HAS_NET_ADMIN=true
fi
if [ "$MODE" = "auto" ]; then
    if [ "$HAS_NET_ADMIN" = true ]; then
        MODE="wireguard"
        echo "[INFO] Обнаружен CAP_NET_ADMIN → режим WireGuard"
    else
        MODE="socks5"
        echo "[WARN] CAP_NET_ADMIN НЕТ (Render Free Tier) → режим SOCKS5 proxy"
        echo "       Для WireGuard нужен платный тариф или VPS"
    fi
fi

# --- Включаем IP forwarding (если позволяет контейнер) ---
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || true

# ============================================================
# РЕЖИМ 1: WireGuard + WSTunnel
# ============================================================
if [ "$MODE" = "wireguard" ]; then
    echo ""
    echo ">>> Инициализация WireGuard..."

    # Генерация ключей сервера
    SERVER_PRIVATE_KEY_FILE="/app/creds/server_private_key"
    SERVER_PUBLIC_KEY_FILE="/app/creds/server_public_key"
    if [ ! -f "$SERVER_PRIVATE_KEY_FILE" ]; then
        wg genkey | tee "$SERVER_PRIVATE_KEY_FILE" | wg pubkey > "$SERVER_PUBLIC_KEY_FILE"
    fi
    SERVER_PRIVATE_KEY=$(cat "$SERVER_PRIVATE_KEY_FILE")
    SERVER_PUBLIC_KEY=$(cat "$SERVER_PUBLIC_KEY_FILE")

    # Создаём базовый конфиг
    cat > /etc/wireguard/${WG_IFACE}.conf <<EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = ${WG_SUBNET}.1/24
ListenPort = ${WG_PORT}
PostUp = iptables -A FORWARD -i ${WG_IFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_IFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

    # Генерация клиентов
    echo ""
    echo "=== КЛИЕНТСКИЕ КОНФИГИ ==="
    for i in $(seq 1 $CLIENTS_COUNT); do
        CLIENT_IP="${WG_SUBNET}.$((i+1))"
        CLIENT_PRIVATE_KEY=$(wg genkey)
        CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
        PRESHARED_KEY=$(wg genpsk)

        # Добавляем пир
        cat >> /etc/wireguard/${WG_IFACE}.conf <<EOF

[Peer] # Client $i
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
PresharedKey = ${PRESHARED_KEY}
EOF

        # Сохраняем клиентский конфиг
        cat > /app/config/client${i}.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = ${WG_DNS}
MTU = 1280

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 127.0.0.1:${WG_PORT}
PersistentKeepalive = 25
EOF

        echo ""
        echo "--- Client $i ---"
        cat /app/config/client${i}.conf
        echo ""
        qrencode -t ansiutf8 < /app/config/client${i}.conf 2>/dev/null || true
    done

    # Запуск WireGuard
    echo ""
    echo ">>> Запуск WireGuard..."
    if wg-quick up ${WG_IFACE} 2>/dev/null; then
        echo "[OK] WireGuard запущен через wg-quick"
    elif wireguard-go ${WG_IFACE} 2>/dev/null &&          ip addr add ${WG_SUBNET}.1/24 dev ${WG_IFACE} 2>/dev/null &&          wg setconf ${WG_IFACE} /etc/wireguard/${WG_IFACE}.conf 2>/dev/null; then
        echo "[OK] WireGuard запущен через wireguard-go (userspace)"
        ip link set up dev ${WG_IFACE}
    else
        echo "[FAIL] Не удалось запустить WireGuard. Переключаюсь на SOCKS5..."
        MODE="socks5"
    fi
fi

# ============================================================
# РЕЖИМ 2: SOCKS5 + WSTunnel (fallback для Render Free)
# ============================================================
if [ "$MODE" = "socks5" ]; then
    echo ""
    echo ">>> Запуск SOCKS5 proxy (microsocks)..."
    microsocks -p ${SOCKS5_PORT} -i 127.0.0.1 &
    MICROSOCKS_PID=$!
    echo "[OK] microsocks запущен на 127.0.0.1:${SOCKS5_PORT} (PID: $MICROSOCKS_PID)"
    echo ""
    echo "=== ИНСТРУКЦИЯ ДЛЯ КЛИЕНТА (SOCKS5) ==="
    echo "1. Запусти wstunnel клиент:"
    echo "   wstunnel client -L 'socks5://127.0.0.1:1080' wss://your-service.onrender.com"
    echo "2. Настрой браузер/приложение на SOCKS5 прокси: 127.0.0.1:1080"
    echo ""
fi

# ============================================================
# Запуск WSTunnel Server
# ============================================================
echo ""
echo ">>> Запуск WSTunnel server на порту $WSTUNNEL_PORT..."

if [ "$MODE" = "wireguard" ]; then
    # Ограничиваем туннель только WireGuard портом
    exec wstunnel server --log-lvl INFO         --restrict-to "127.0.0.1:${WG_PORT}"         "ws://0.0.0.0:${WSTUNNEL_PORT}"
else
    # SOCKS5 режим — ограничиваем только SOCKS5 порт
    exec wstunnel server --log-lvl INFO         --restrict-to "127.0.0.1:${SOCKS5_PORT}"         "ws://0.0.0.0:${WSTUNNEL_PORT}"
fi
