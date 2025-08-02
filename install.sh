#!/bin/bash

echo -e "=== 🚀 Установка VLESS VPN Сервера ==="
echo -e "Автор: Artem Griganov (@iamnovye)\n"

# === Ввод данных ===
read -p "🌍 Введите домен (A-запись должна указывать на сервер): " DOMAIN
read -p "🧠 Введите публичный IP сервера: " SERVER_IP
read -p "👤 Логин администратора Marzban: " ADMIN_USER
read -s -p "🔐 Пароль администратора: " ADMIN_PASS
echo ""

INSTALL_DIR="/opt/vless-vpn-server"

# === Очистка старой установки, если нужно ===
if [ -d "$INSTALL_DIR" ]; then
  echo "[!] Найдена предыдущая установка. Удаляю..."
  docker compose -f $INSTALL_DIR/docker-compose.yml down 2>/dev/null
  rm -rf "$INSTALL_DIR"
fi

# === Установка зависимостей ===
echo -e "[+] Установка зависимостей..."
apt update -qq
apt install -y curl wget git unzip socat ufw certbot python3-certbot docker.io docker-compose

# === Открытие портов ===
echo -e "[+] Открытие портов..."
ufw allow 443
ufw allow 80
ufw --force enable

# === Получение SSL сертификата ===
echo -e "[+] Получение SSL сертификата для $DOMAIN..."
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || {
  echo "[!] Ошибка при получении сертификата"; exit 1;
}

CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
FULLCHAIN="$CERT_DIR/fullchain.pem"
PRIVKEY="$CERT_DIR/privkey.pem"

if [ ! -f "$FULLCHAIN" ] || [ ! -f "$PRIVKEY" ]; then
  echo "[!] Сертификаты не найдены"; exit 1
fi

# === Клонирование репозитория Marzban ===
echo -e "[+] Клонирование Marzban..."
git clone https://github.com/Gozargah/Marzban.git "$INSTALL_DIR"

cd "$INSTALL_DIR"

# === Генерация UUID и ключей ===
UUID=$(cat /proc/sys/kernel/random/uuid)
PRIVATE_KEY=$(openssl ecparam -genkey -name prime256v1 | openssl ec -outform PEM)
SHORT_ID=$(openssl rand -hex 4)

# === Создание .env ===
echo -e "[+] Создание .env файла..."
cat <<EOF > .env
DOMAIN=$DOMAIN
UUID=$UUID
PRIVATE_KEY=$PRIVATE_KEY
SHORT_ID=$SHORT_ID
ADMIN_USERNAME=$ADMIN_USER
ADMIN_PASSWORD=$ADMIN_PASS
CERT_FULLCHAIN=$FULLCHAIN
CERT_PRIVKEY=$PRIVKEY
EOF

# === Запуск контейнеров ===
echo -e "[+] Запуск контейнеров..."
docker compose up -d

# === Готово ===
echo -e "✅ Установка завершена!"
echo -e "🌐 Панель доступна: https://$DOMAIN/dashboard"
echo -e "🔑 Логин: $ADMIN_USER"
echo -e "🔐 Пароль: $ADMIN_PASS"
