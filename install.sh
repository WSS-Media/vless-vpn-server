#!/bin/bash

set -e

echo -e "\n=== 🚀 Установка VLESS VPN Сервера ==="
echo -e "Автор: Artem Griganov (@iamnovye)\n"

read -p "🌍 Введите домен (A-запись должна указывать на сервер): " DOMAIN
read -p "🧠 Введите публичный IP сервера: " SERVER_IP
read -p "👤 Логин администратора Marzban: " ADMIN_USER
read -s -p "🔐 Пароль администратора: " ADMIN_PASS
echo ""

# Function to clean up previous installation
cleanup() {
  echo "[*] Выполняется очистка предыдущей установки..."
  docker compose down || true
  rm -rf /opt/vless-vpn-server
  rm -rf /var/lib/marzban
  rm -rf /etc/letsencrypt/live/$DOMAIN
  rm -rf /etc/letsencrypt/archive/$DOMAIN
  rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf
  echo "[*] Очистка завершена."
}

# Confirm retry if an error occurs
trap 'echo -e "\n[!] Установка не удалась. Хотите начать заново? (Y/N)"; read answer; if [[ $answer == "Y" || $answer == "y" ]]; then cleanup && exec $0; else echo "🚫 Установка прервана."; exit 1; fi' ERR

echo "[+] Установка зависимостей..."
apt update -y
apt install -y curl wget git unzip ufw certbot socat python3-certbot

echo "[+] Открытие портов..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "[+] Клонирование репозитория..."
git clone https://github.com/WSS-Media/vless-vpn-server /opt/vless-vpn-server

echo "[+] Установка Xray..."
wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /usr/local/bin/xray
chmod +x /usr/local/bin/xray/xray
ln -sf /usr/local/bin/xray/xray /usr/local/bin/xray

echo "[+] Получение SSL сертификата для $DOMAIN..."
systemctl stop nginx || true
certbot certonly --standalone --preferred-challenges http -d $DOMAIN --register-unsafely-without-email --agree-tos

echo "[+] Генерация UUID, privateKey и shortId..."
UUID=$(xray uuid)
PRIVATE_KEY=$(openssl ecparam -name prime256v1 -genkey -noout | openssl ec -text -noout | grep 'priv:' -A 3 | tail -n +2 | tr -d '\n[:space:]:')

echo "[+] Подготовка .env файла..."
mkdir -p /var/lib/marzban/certs
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /var/lib/marzban/certs/
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /var/lib/marzban/certs/key.pem
chmod 644 /var/lib/marzban/certs/*.pem

cat <<EOF > /opt/vless-vpn-server/.env
DOMAIN=$DOMAIN
IP=$SERVER_IP
UUID=$UUID
PRIVATE_KEY=$PRIVATE_KEY
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
EOF

echo "[+] Установка завершена. Продолжайте установку по инструкции или автоматически в следующей версии."
