#!/bin/bash

set -e

echo -e "\n=== 🚀 Установка VLESS VPN Сервера ==="
echo "Автор: Artem Griganov (@iamnovye)"
echo

read -p "🌍 Введите домен (A-запись должна указывать на сервер): " DOMAIN
read -p "🧠 Введите публичный IP сервера: " SERVER_IP
read -p "👤 Логин администратора Marzban: " ADMIN_USERNAME
read -s -p "🔐 Пароль администратора: " ADMIN_PASSWORD
echo

echo -e "\n[+] Установка зависимостей..."
apt update -qq
apt install -y curl wget git ufw unzip docker.io docker-compose certbot python3-certbot socat jq

echo -e "\n[+] Открытие порта 443..."
ufw allow 443/tcp
ufw allow 443/udp
ufw enable

echo -e "\n[+] Установка Docker..."
systemctl start docker
systemctl enable docker

echo -e "\n[+] Установка Marzban..."
MARZBAN_DIR="/opt/marzban"
rm -rf $MARZBAN_DIR
git clone https://github.com/Gozargah/Marzban.git $MARZBAN_DIR
cd $MARZBAN_DIR

echo -e "\n[+] Генерация .env..."
UUID=$(cat /proc/sys/kernel/random/uuid)
PRIVATE_KEY=$(openssl ecparam -name prime256v1 -genkey -noout | openssl ec -outform PEM)
echo -e "DOMAIN=$DOMAIN\nUUID=$UUID" > .env

cat <<EOF > docker-compose.override.yml
services:
  web:
    ports:
      - "443:443"
    environment:
      - CERTBOT_EMAIL=admin@$DOMAIN
EOF

echo -e "\n[+] Получение SSL сертификата..."
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || true

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "[!] Сертификат не получен. Прерывание установки."
    exit 1
fi

mkdir -p data/certs
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem data/certs/fullchain.pem
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem data/certs/key.pem

echo -e "\n[+] Запуск Marzban..."
docker compose down || true
docker compose up -d

echo -e "\n✅ Установка завершена!"
echo "🌐 Панель доступна: https://$DOMAIN"
echo "👤 Логин: $ADMIN_USERNAME"
echo "🔐 Пароль: $ADMIN_PASSWORD"
