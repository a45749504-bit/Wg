# Переменные окружения для Render.com

## Обязательные (без них сервер не запустится)

| Переменная | Описание | Как получить |
|------------|----------|--------------|
| `WSTUNNEL_SECRET` | Защитный путь для WebSocket upgrade. Минимум 32 символа. | `openssl rand -base64 32` |
| `CLIENT_PUBLIC_KEY` | Публичный ключ WireGuard клиента | `wg genkey \| tee privatekey \| wg pubkey > publickey` |

## Опциональные

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `PRESHARED_KEY` | авто-генерация | Доп. ключ для защиты от квантовых атак. `wg genpsk` |
| `CLIENT_PUBLIC_KEY_2` | — | Публичный ключ второго клиента |
| `CLIENT_PUBLIC_KEY_3` | — | Публичный ключ третьего клиента |
| `WG_PORT` | `51820` | Порт WireGuard |
| `WG_SUBNET` | `10.200.200.0/24` | Подсеть WireGuard |
| `WG_SERVER_IP` | `10.200.200.1` | IP сервера в подсети |
| `WG_CLIENT_IP` | `10.200.200.2` | IP первого клиента |
| `DNS_SERVERS` | `1.1.1.1,8.8.8.8` | DNS-серверы через запятую |

## Предустановленные Render (не трогай)

| Переменная | Описание |
|------------|----------|
| `PORT` | Порт, на котором должен слушать сервер (Render назначает автоматически) |

## Пример заполнения

```
WSTUNNEL_SECRET=xK9#mP2$vL7@nQ4&wR8*tY3^hJ6!bF1
CLIENT_PUBLIC_KEY=AbCdEfGhIjKlMnOpQrStUvWxYz1234567890abcdefg=
PRESHARED_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
DNS_SERVERS=1.1.1.1,8.8.8.8
```

## Как задать переменные

1. Открой Dashboard → твой сервис → **Environment**
2. Нажми **Add Environment Variable**
3. Введи `Key` и `Value`
4. Нажми **Save Changes**
5. Перезапусти сервис (Manual Deploy → Deploy Latest Commit)

## Примечание о безопасности

- `WSTUNNEL_SECRET` — это НЕ пароль, а часть URL-пути. Даже если кто-то узнает домен сервера, без правильного secret подключиться невозможно.
- `PRESHARED_KEY` добавляет симметричное шифрование поверх асимметричного WireGuard — защита от будущих квантовых компьютеров.
- Никогда не коммить реальные ключи в Git! Используй Environment Variables.
