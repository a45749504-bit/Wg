#!/bin/bash
set -e
SERVER_URL="${1:-}"
SECRET="${2:-}"
if [ -z "$SERVER_URL" ] || [ -z "$SECRET" ]; then
    echo "Usage: bash client-setup.sh <wss://your-app.onrender.com> <secret>"
    exit 1
fi

echo "Installing dependencies..."
if command -v pkg &> /dev/null; then
    pkg update -y -o Dpkg::Options::="--force-confold"
    pkg install -y wireguard-tools curl tar
else
    apt-get update -qq && apt-get install -y -qq wireguard-tools curl tar
fi

echo "Preparing wstunnel..."
ARCH=$(uname -m)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$ARCH" = "aarch64" ]; then BIN="wstunnel-linux-arm64"; URL="https://github.com/erebe/wstunnel/releases/download/v10.6.2/wstunnel_10.6.2_linux_arm64.tar.gz"; fi
if [ "$ARCH" = "x86_64" ]; then BIN="wstunnel-linux-amd64"; URL="https://github.com/erebe/wstunnel/releases/download/v10.6.2/wstunnel_10.6.2_linux_amd64.tar.gz"; fi

if [ -f "${SCRIPT_DIR}/bin/${BIN}" ]; then
    echo "  Using local binary from bin/"
    cp "${SCRIPT_DIR}/bin/${BIN}" ./wstunnel
else
    echo "  Downloading from GitHub..."
    curl -fsSL -A "Mozilla/5.0" -o /tmp/a.tar.gz "$URL"
    tar -xzf /tmp/a.tar.gz -C /tmp && cp $(find /tmp -name wstunnel -type f | head -1) ./wstunnel
    rm -rf /tmp/a.tar.gz /tmp/wstunnel*
fi
chmod +x ./wstunnel && ./wstunnel --version

echo "Generating WireGuard keys..."
CLIENT_PRIVATE=$(wg genkey)
CLIENT_PUBLIC=$(echo "$CLIENT_PRIVATE" | wg pubkey)
PRESHARED=$(wg genpsk)

echo ""
echo "=== CLIENT KEYS (SAVE THESE!) ==="
echo "Client Public Key:  ${CLIENT_PUBLIC}"
echo "PresharedKey:       ${PRESHARED}"
echo ""
echo "Paste Client Public Key into Render as CLIENT_PUBLIC_KEY"
echo ""

mkdir -p wireguard-config
cat > wireguard-config/wg-client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = 10.200.200.2/24
DNS = 1.1.1.1, 8.8.8.8
[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
PresharedKey = ${PRESHARED}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 127.0.0.1:51820
PersistentKeepalive = 25
EOF

echo "Config saved: wireguard-config/wg-client.conf"

cat > start-tunnel.sh <<EOF
#!/bin/bash
echo "Starting wstunnel client..."
./wstunnel client --http-upgrade-path-prefix "${SECRET}" -L "udp://51820:localhost:51820?timeout_sec=0" "${SERVER_URL}"
EOF
chmod +x start-tunnel.sh
echo "Start script created: start-tunnel.sh"
