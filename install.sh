#!/bin/bash

clear
echo "=== 🚀 Установка VLESS VPN Сервера ==="
echo "Автор: Artem Griganov (@iamnovye)"
echo

# Проверка sudo
if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт от root пользователя."
  exit 1
fi

# Запрашиваем данные
read -p "🌍 Введите домен (A-запись должна указывать на сервер): " DOMAIN
read -p "🧠 Введите публичный IP сервера: " IP
read -p "👤 Логин администратора Marzban: " ADMIN_USER
read -s -p "🔐 Пароль администратора: " ADMIN_PASS
echo

WORKDIR="/opt/vless-vpn-server"
TEMP_SCRIPT="/tmp/install_vless.sh"

function clean_up() {
  echo "[*] Выполняется очистка предыдущей установки..."
  systemctl stop docker >/dev/null 2>&1
  apt-get remove -y docker docker.io containerd runc >/dev/null 2>&1
  rm -rf $WORKDIR /var/lib/marzban /opt/marzban /etc/letsencrypt/live/$DOMAIN /etc/letsencrypt/archive/$DOMAIN
  echo "[*] Очистка завершена."
}

function install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "[+] Установка Docker..."
    curl -fsSL https://get.docker.com | bash
  fi
}

function fail_prompt() {
  echo "[!] Установка не удалась. Хотите начать заново? (Y/N)"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    clean_up
    curl -s https://raw.githubusercontent.com/WSS-Media/vless-vpn-server/main/install.sh -o $TEMP_SCRIPT
    chmod +x $TEMP_SCRIPT
    bash $TEMP_SCRIPT
    exit
  else
    echo "⛔ Установка прервана."
    exit 1
  fi
}

# Установка зависимостей
echo "[+] Установка зависимостей..."
apt update && apt install -y curl wget git ufw certbot python3-certbot socat unzip || fail_prompt

# Открытие портов
echo "[+] Открытие портов..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Клонирование репозитория
echo "[+] Клонирование репозитория..."
if [ -d "$WORKDIR" ]; then
  echo "[!] Папка $WORKDIR уже существует."
  fail_prompt
fi
git clone https://github.com/WSS-Media/vless-vpn-server.git $WORKDIR || fail_prompt

# Получение SSL
echo "[+] Получение SSL сертификата для $DOMAIN..."
certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$DOMAIN" || fail_prompt

# Генерация данных
echo "[+] Генерация UUID, privateKey и shortId..."
UUID=$(cat /proc/sys/kernel/random/uuid)
PRIVATE_KEY=$(openssl ecparam -genkey -name prime256v1 -noout | openssl ec -outform DER | base64)
SHORT_ID=$(head -c 8 /dev/urandom | xxd -p)

# Установка Docker
install_docker || fail_prompt

# Запуск основного установщика
echo "[+] Запуск основного установщика..."
cd $WORKDIR || fail_prompt
bash internal/install_core.sh "$DOMAIN" "$IP" "$UUID" "$PRIVATE_KEY" "$SHORT_ID" "$ADMIN_USER" "$ADMIN_PASS" || fail_prompt

echo
echo "✅ Установка завершена. Панель доступна по адресу: https://$DOMAIN"
echo "🧑‍💼 Логин: $ADMIN_USER"
echo "🔑 Пароль: $ADMIN_PASS"
