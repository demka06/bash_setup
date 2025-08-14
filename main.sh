#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Запустите скрипт с sudo!"
    exit 1
fi

sudo chmod +x ./src/setup.sh
sudo chmod +x ./src/add_user.sh

while true; do
    echo "Выберите действие:"
    echo "1) Сконфигурировать сервер"
    echo "2) Добавить пользователя"
    echo "3) Выйти"
    read -rp "Введите номер опции: " choice

    case "$choice" in
        1)
            echo "Запуск скрипта конфигурации сервера..."
            ./src/setup.sh
            ;;
        2)
            echo "Запуск скрипта добавления пользователя..."
            ./src/add_user.sh
            ;;
        3)
            echo "Выход."
            exit 0
            ;;
        *)
            echo "Неверный выбор, введите 1, 2 или 3."
            ;;
    esac

done
