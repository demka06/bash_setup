#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo
    echo "Запусти скрипт с sudo!"
    echo
    exit 1
fi



NGINX_BIN=$(command -v nginx 2>/dev/null || true)

# ===== ПРОВЕРКА NGINX =====
if ! [[ -z "$NGINX_BIN" ]]; then
    echo
    echo "Nginx уже установлен."
    echo
    exit 0
fi

apt-get install nginx certbot python-certbot-nginx -y

ufw allow 443/tcp
ufw allow 80/tcp
ufw disable
ufw --force enable

echo
echo "Установлены следующие пакеты: certbot python-certbot-nginx. Открыты 443 и 80 порт"
echo