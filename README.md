# WireGuard + Wstunnel on Render.com

## Quick Start

### Step 0: Download binaries (run once locally)
```bash
bash download-binaries.sh
```

### Step 1: Push to GitHub
```bash
git add .
git commit -m "init"
git push
```

### Step 2: Deploy on Render.com
1. Dashboard → New → Web Service → connect your repo
2. Set Environment Variables:
   - `WSTUNNEL_SECRET` — random string, min 32 chars
   - `CLIENT_PUBLIC_KEY` — leave empty for now
3. Click Deploy
4. Check logs for Server Public Key

### Step 3: Generate client keys
On Android (Termux) or Linux:
```bash
bash client-setup.sh wss://your-app.onrender.com your-secret
```

Paste the generated **Client Public Key** into Render's `CLIENT_PUBLIC_KEY`.

### Step 4: Connect
1. Termux: `./start-tunnel.sh`
2. WireGuard app: import `wireguard-config/wg-client.conf` and enable
3. Check your IP at 2ip.ru

## Files
- `Dockerfile` — uses `bin/wstunnel-linux-amd64`
- `entrypoint.sh` — server startup
- `download-binaries.sh` — downloads wstunnel into `bin/`
- `client-setup.sh` — client key generation
- `render.yaml` — Render Blueprint
- `ENV_VARIABLES.md` — env var documentation
