#!/bin/bash
# Marzban Auto Deployment Script
# Author: Artem Griganov (@iamnovye)
# GitHub: https://github.com/your-repo-if-needed


set -e

echo "🛠️  Marzban + VLESS REALITY Installer"

# === ПОЛЬЗОВАТЕЛЬСКИЙ ВВОД ===
read -rp "📌 Введите домен (например: vpn.example.com): " DOMAIN
read -rp "📧 Введите email (для Let's Encrypt): " EMAIL
read -rp "👤 Введите имя администратора: " ADMIN_USERNAME
read -rsp "🔐 Введите пароль администратора: " ADMIN_PASSWORD
echo
read -rp "👥 Введите имя VLESS клиента: " CLIENT_NAME

# === СЛУЖЕБНЫЕ ПЕРЕМЕННЫЕ ===
UUID=$(uuidgen)
PRIVATE_KEY=$(openssl ecparam -name prime256v1 -genkey -noout | openssl ec -text -noout | grep -A5 "priv:" | tail -n +2 | tr -d ': ' | tr -d '\n' | cut -c1-64)
SHORT_ID=$(openssl rand -hex 8)

# === УСТАНОВКА ЗАВИСИМОСТЕЙ ===
apt update && apt install -y curl socat cron bash unzip sqlite3 certbot python3-certbot

# === УСТАНОВКА DOCKER ===
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker-compose &> /dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# === КЛОНИРОВАНИЕ MARZBAN ===
cd /opt
git clone https://github.com/Gozargah/Marzban.git marzban
cd marzban

# === .env ===
cat <<EOF > .env
DOMAIN=$DOMAIN
PANEL_URL=https://$DOMAIN
EMAIL=$EMAIL
XRAY_VLESS_REALITY_PRIVATE_KEY=$PRIVATE_KEY
XRAY_VLESS_REALITY_SHORT_ID=$SHORT_ID
EOF

# === СЕРТИФИКАТЫ ===
systemctl stop nginx 2>/dev/null || true
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN

mkdir -p /var/lib/marzban/certs
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /var/lib/marzban/certs/fullchain.pem
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /var/lib/marzban/certs/key.pem
chmod 644 /var/lib/marzban/certs/*.pem

# === ЗАПУСК MARZBAN ===
docker-compose down || true
docker-compose up -d

sleep 10

# === СОЗДАНИЕ АДМИНА ===
docker exec -i marzban-marzban-1 marzban add-user --username $ADMIN_USERNAME --password $ADMIN_PASSWORD --is_admin true

# === ДОБАВЛЕНИЕ VLESS-КЛИЕНТА ===
docker exec -i marzban-marzban-1 marzban add-client --username $CLIENT_NAME --uuid $UUID --inbound-tag VLESS_TCP_REALITY

# === ВЫВОД ДАННЫХ ===
echo "✅ Установка завершена!"
echo "🔗 Панель: https://$DOMAIN"
echo "👤 Админ: $ADMIN_USERNAME"
echo "📱 VLESS UUID: $UUID"
echo "🔑 PRIVATE KEY: $PRIVATE_KEY"
echo "🧬 SHORT ID: $SHORT_ID"
