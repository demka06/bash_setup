#!/bin/bash

set -e

# ===== ПРОВЕРКА ПРАВ =====
if [[ $EUID -ne 0 ]]; then
    echo "Запусти с sudo!"
    exit 1
fi

CRON_JOB="30 2 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
read -rp "Введите домен: " DOMAIN

# ===== ПРОВЕРКА ОСТАНОВЛЕН ЛИ NGINX =====
if ss -tuln | grep -E -q ":80(\s|$)"; then
    systemctl stop nginx
fi

# ===== ВЫДАЧА СЕРТИФИКАТА =====
certbot certonly --standalone -d "$DOMAIN" \
 --non-interactive --agree-tos \
  --force-renewal -m mail@gmail.ru

systemctl start nginx

echo
echo "Сертификат для $DOMAIN выдан"
echo

# ===== ДОБАВЛЕНИЕ ЗАДАЧИ В CRON =====
if ! crontab -l | grep -Fq "$CRON_JOB"; then
    # Добавляем задачу в crontab root
    (crontab -l 2>/dev/null | grep -Fv "certbot renew"; echo "$CRON_JOB") | crontab -
fi

echo
echo "Cron настроен для автоматического обновления сертификатов."
echo