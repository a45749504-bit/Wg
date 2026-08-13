# WireGuard + WSTunnel для Render.com

VPN-сервер на базе WireGuard, замаскированный под WebSocket через WSTunnel. Работает на Render Free Tier в режиме SOCKS5 proxy, а на платных тарифах/VPS — в полноценном режиме WireGuard.

## Архитектура

```
[Клиент] → [WSTunnel Client] → WebSocket/HTTPS → [Render] → [WSTunnel Server] → [WireGuard или SOCKS5] → Интернет
```

## Переменные окружения

| Переменная | Обязательная | По умолчанию | Описание |
|------------|-------------|--------------|----------|
| `PORT` | ✅ Да (Render даёт автоматически) | — | Порт, на котором слушает WSTunnel. **Не менять вручную на Render!** |
| `MODE` | Нет | `auto` | `auto` / `wireguard` / `socks5`. `auto` выбирает wireguard при наличии `NET_ADMIN`, иначе `socks5` |
| `WG_SUBNET` | Нет | `10.200.200` | Подсеть WireGuard (последний октет не указывай) |
| `WG_DNS` | Нет | `1.1.1.1,8.8.8.8` | DNS-серверы для клиентов |
| `WG_PORT` | Нет | `51820` | Внутренний порт WireGuard в контейнере |
| `SOCKS5_PORT` | Нет | `1080` | Порт SOCKS5 proxy (fallback режим) |
| `CLIENTS_COUNT` | Нет | `1` | Сколько клиентских конфигов сгенерировать при старте |

## Быстрый старт

### 1. Деплой на Render (через Blueprint)

1. Форкни/склонируй этот репозиторий на GitHub
2. В Render Dashboard нажми **New → Blueprint**
3. Выбери свой репозиторий — Render сам прочитает `render.yaml`
4. Нажми **Apply**

### 2. Деплой на Render (вручную)

1. **New → Web Service** → выбери репозиторий
2. **Runtime**: Docker
3. **Plan**: Free
4. В разделе **Environment** добавь переменные из `.env.example` (кроме `PORT`)
5. **Create Web Service**

### 3. Получение конфигов

Открой **Logs** в Render Dashboard. Там будут:
- QR-коды для телефонов
- Текстовые `.conf` файлы

**Важно:** на Render Free Tier контейнер запустится в режиме **SOCKS5** (нет `CAP_NET_ADMIN`). Для WireGuard нужен платный тариф или VPS.

### 4. Подключение клиента

#### Режим WireGuard (платный Render / VPS / Docker локально)

```bash
# Терминал 1: WSTunnel клиент
wstunnel client   -L 'udp://51820:127.0.0.1:51820?timeout_sec=0'   wss://your-service-name.onrender.com

# Терминал 2: WireGuard
sudo wg-quick up ./client1.conf
```

#### Режим SOCKS5 (Render Free Tier)

```bash
# Запусти wstunnel клиент
wstunnel client   -L 'socks5://127.0.0.1:1080'   wss://your-service-name.onrender.com

# Настрой браузер/систему на SOCKS5 прокси: 127.0.0.1:1080
```

**Firefox:** Settings → Network → Manual proxy → SOCKS5 `127.0.0.1:1080`

**Chrome:** запускай с флагом `--proxy-server="socks5://127.0.0.1:1080"`

**Android:** Termux + `wstunnel client ...` + приложение ProxyDroid или настройка Wi-Fi прокси

**iOS:** Shadowrocket / Stash с поддержкой WSTunnel

### 5. Держи контейнер "теплым"

Render Free засыпает через 15 мин без HTTP-запросов:
1. [uptimerobot.com](https://uptimerobot.com) → Add Monitor
2. Type: HTTP(S), URL: `https://your-service.onrender.com`
3. Interval: 5 minutes

## Локальное тестирование (Docker)

```bash
cp .env.example .env
# Отредактируй .env при необходимости
docker-compose up --build
```

Локально с `cap_add: NET_ADMIN` будет работать полноценный WireGuard.

## Генерация дополнительных клиентов

В Shell Render Dashboard:
```bash
/app/gen-client.sh 10   # IP будет 10.200.200.10
```

## Траблшутинг

| Проблема | Решение |
|----------|---------|
| `PORT not set` | На Render переменная `PORT` создаётся автоматически. Локально запускай с `-e PORT=8080` |
| `Cannot allocate TUN` | Нет `CAP_NET_ADMIN`. Используй `MODE=socks5` или платный тариф |
| Контейнер засыпает | UptimeRobot каждые 5 мин |
| Нет интернета в WG | Проверь `AllowedIPs = 0.0.0.0/0` и `Endpoint = 127.0.0.1:51820` |

## Лицензия

MIT
