#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo
    echo "Запусти скрипт с sudo!"
    echo
    exit 1
fi

# ===== ПРОВЕРКА NGINX =====
if dpkg -l nginx &> /dev/null; then
    echo
    echo "Nginx уже установлен."
    echo
    exit 0
fi

apt-get update
apt-get install nginx certbot python3-certbot-nginx -y

ufw allow 80,443/tcp
ufw disable
ufw --force enable

echo
echo "Установлены следующие пакеты: certbot python3-certbot-nginx. Открыты 443 и 80 порт"
echo