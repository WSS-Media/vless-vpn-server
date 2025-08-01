#!/bin/bash

# ┌───────────────────────────────────────────────┐
# │  VLESS VPN Server Installer by Artem Griganov │
# │     Instagram: @iamnovye                      │
# └───────────────────────────────────────────────┘

set -e

echo -e "\n=== 🚀 Установка VLESS VPN Сервера ==="
echo "Автор: Artem Griganov (@iamnovye)\n"

# ─────── Ввод данных ────────────────

read -rp "🌍 Введите домен (A-запись должна указывать на сервер): " DOMAIN
read -rp "🧠 Введите публичный IP сервера: " SERVER_IP
read -rp "👤 Логин администратора Marzban: " ADMIN_USER
read -rsp "🔐 Пароль администратора: " ADMIN_PASS; echo

# ─────── Зависимости ────────────────

echo "[+] Установка зависимостей..."
apt update -y
apt install -y curl wget git socat ufw certbot python3-certbot

# ─────── Настройка брандмауэра ───────

echo "[+] Открытие портов..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# ─────── Клонирование репозитория ──

echo "[+] Клонирование репозитория..."
git clone https://github.com/WSS-Media/vless-vpn-server.git /opt/vless-vpn-server
cd /opt/vless-vpn-server

# ─────── Получение SSL ──────────────

echo "[+] Получение SSL сертификата для $DOMAIN..."
certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$DOMAIN" --non-interactive

mkdir -p /var/lib/marzban/certs/
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /var/lib/marzban/certs/fullchain.pem
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /var/lib/marzban/certs/key.pem
chmod 644 /var/lib/marzban/certs/*.pem

# ─────── Генерация ключей ──────────

echo "[+] Генерация UUID, privateKey и shortId..."
UUID=$(cat /proc/sys/kernel/random/uuid)
PRIVATE_KEY=$(xray x25519 | grep 'Private key' | awk '{print $NF}')
SHORT_ID=$(openssl rand -hex 8)

# ─────── Настройка ENV ─────────────

echo "[+] Подготовка .env..."
cat > .env <<EOF
DOMAIN=$DOMAIN
UUID=$UUID
PRIVATE_KEY=$PRIVATE_KEY
SHORT_ID=$SHORT_ID
ADMIN_USERNAME=$ADMIN_USER
ADMIN_PASSWORD=$ADMIN_PASS
EOF

# ─────── Запуск установки ──────────

echo "[+] Запуск установщика..."
bash internal/install_core.sh

# ─────── Финал ─────────────────────

echo -e "\n✅ Установка завершена!"
echo "🌐 Панель: https://$DOMAIN"
echo "👤 Логин: $ADMIN_USER"
echo "🔐 Пароль: $ADMIN_PASS"
echo "📡 UUID: $UUID"
echo "🗝️  Reality Private Key: $PRIVATE_KEY"
echo "🔎 Short ID: $SHORT_ID"
