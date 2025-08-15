#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo
    echo "Запусти скрипт с sudo!"
    echo
    exit 1
fi

if command -v nginx >/dev/null 2>&1; then
echo
    echo "Nginx уже установлен."
    echo
    exit 1
fi

apt-get install nginx certbot python-certbot-nginx -y

ufw allow 443/tcp
ufw allow 80/tcp

echo
echo "Установлены следующие пакеты: certbot python-certbot-nginx. Открыты 443 и 80 порт"
echo