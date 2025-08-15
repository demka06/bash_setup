#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Запустите скрипт с sudo!"
    exit 1
fi

chmod +x ./src/setup.sh
chmod +x ./src/administration/add_user.sh
chmod +x ./src/fail2ban/add_nginx.sh
chmod +x ./src/nginx/create_cert.sh
chmod +x ./src/nginx/setup_nginx.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while true; do
    echo ""
    echo "Выберите действие:"
    echo "1) Сконфигурировать сервер"
    echo "2) Добавить пользователя"
    echo "3) Настроить nginx и certbot (установка)"
    echo "4) Получить SSL-сертификат"
    echo "5) Настроить fail2ban для nginx"
    echo "6) Выйти"
    read -rp "Введите номер опции: " choice

    case "$choice" in
        1)
            "$SCRIPT_DIR/src/setup.sh" || echo "Ошибка при выполнении setup.sh"
            ;;
        2)
            "$SCRIPT_DIR/src/administration/add_user.sh" || echo "Ошибка при выполнении add_user.sh"
            ;;
        3)
            "$SCRIPT_DIR/src/nginx/setup_nginx.sh" || echo "Ошибка при выполнении setup_nginx.sh"
            ;;
        4)
            "$SCRIPT_DIR/src/nginx/create_cert.sh" || echo "Ошибка при выполнении create_cert.sh"
            ;;
        5)
            "$SCRIPT_DIR/src/fail2ban/add_nginx.sh" || echo "Ошибка при выполнении add_nginx.sh"
            ;;
        6)
            echo "Выход."
            exit 0
            ;;
        *)
            echo "Неверный выбор, введите от 1 до 6."
            ;;
    esac
done
