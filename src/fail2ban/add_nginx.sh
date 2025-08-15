#!/bin/bash

set -e

# ===== ПРОВЕРКА ПРАВ =====
if [[ $EUID -ne 0 ]]; then
    echo
    echo "Запусти скрипт с sudo!"
    echo
    exit 1
fi

# ===== ПРОВЕРКА NGINX =====
if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx не установлен. Выполняется установка"
    /../nginx/setup_nginx.sh
    exit 1
fi

# ===== СОЗДАНИЕ ФИЛЬТРА =====
tee /etc/fail2ban/filter.d/nginx-noscript.conf > /dev/null << EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (403|404|444) .*$
ignoreregex =
EOF

# ===== ДОБАВЛЕНИЕ СЕКЦИИ NGINX В КОНФИГУРАЦИЮ =====
if [ ! -f /etc/fail2ban/jail.local ]; then
    sudo touch /etc/fail2ban/jail.local
fi

tee -a /etc/fail2ban/jail.local > /dev/null << EOF

[nginx-noscript]
enabled  = true
port     = http,https
filter   = nginx-noscript
logpath  = /var/log/nginx/access.log
maxretry = 5
findtime = 600
bantime  = 86400
EOF

systemctl restart fail2ban

sudo fail2ban-client status nginx-noscript

echo
echo "Конфигурирование fail2ban завершено"
echo