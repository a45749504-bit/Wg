#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Downloading wstunnel binaries..."
curl -fsSL -A "Mozilla/5.0" -o /tmp/a.tar.gz "https://github.com/erebe/wstunnel/releases/download/v10.6.2/wstunnel_10.6.2_linux_amd64.tar.gz"
tar -xzf /tmp/a.tar.gz -C /tmp && cp $(find /tmp -name wstunnel -type f | head -1) bin/wstunnel-linux-amd64
rm -rf /tmp/a.tar.gz /tmp/wstunnel*
curl -fsSL -A "Mozilla/5.0" -o /tmp/a.tar.gz "https://github.com/erebe/wstunnel/releases/download/v10.6.2/wstunnel_10.6.2_linux_arm64.tar.gz"
tar -xzf /tmp/a.tar.gz -C /tmp && cp $(find /tmp -name wstunnel -type f | head -1) bin/wstunnel-linux-arm64
rm -rf /tmp/a.tar.gz /tmp/wstunnel*
chmod +x bin/wstunnel-linux-*
echo "Done!"
ls -la bin/
