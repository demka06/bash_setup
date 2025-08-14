#!/bin/bash

USER_PASS=$(pwgen 32 1)

# ===== ПРОВЕРКА ПРАВ =====
if [[ $EUID -ne 0 ]]; then
    echo "Запусти скрипт с sudo!"
    exit 1
fi
# ===== ПОЛУЧЕНИЕ ИМЕНИ ПОЛЬЗОВАТЕЛЯ =====
read -rp "Введите имя нового пользователя: " USER_NAME
USER_NAME=$(echo "$USER_NAME" | xargs)
while id "$USER_NAME" &>/dev/null || [[ -z "$USER_NAME" ]]; do
    read -rp "Пользователь уже существует или имя пустое. Введите другое имя: " USER_NAME
    USER_NAME=$(echo "$USER_NAME" | xargs)
done

# ===== ПОЛУЧЕНИЕ SSH КЛЮЧА =====
read -rp "Вставьте публичный ключ (ssh-ed25519...): " PUB_KEY
while [[ ! "$PUB_KEY" =~ ^ssh- ]]; do
    read -rp "Ключ должен начинаться с ssh-. Вставьте снова: " PUB_KEY
done

# ===== ПРОВЕРКА =====
echo
echo "===== Данные доступа ====="
echo "Пользователь: $USER_NAME"
echo "Пароль: $USER_PASS"
echo "=========================="
echo
while true; do
    read -rp "Всё верно? (Y/N): " USER_ANSW
    case "$USER_ANSW" in
        [Yy])
            echo "Продолжаю установку!"
            break
            ;;
        [Nn])
            echo "Выполнение остановлено!"
            exit 0
            ;;
        *)
            echo "Неверный ввод, введите Y или N"
            ;;

    esac
done

# ===== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ С ПАРОЛЕМ И SUDO =====
adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG sudo "$USER_NAME"
echo "$USER_NAME:$USER_PASS" | sudo chpasswd

# ===== СОЗДАНИЕ .ssh И ДОБАВЛЕНИЕ ПУБЛИЧНОГО КЛЮЧА =====
# Создание папки .ssh
sudo -u "$USER_NAME" mkdir -p /home/"$USER_NAME"/.ssh
# Установка прав и владельца на папку .ssh
chmod 700 /home/"$USER_NAME"/.ssh
chown -R "$USER_NAME:$USER_NAME" /home/"$USER_NAME"/.ssh
# Добавление ключа
echo "$PUB_KEY" | sudo tee /home/"$USER_NAME"/.ssh/authorized_keys > /dev/null
# Установка прав и владельца на authorized_keys
chmod 600 /home/"$USER_NAME"/.ssh/authorized_keys
chown "$USER_NAME:$USER_NAME" /home/"$USER_NAME"/.ssh/authorized_keys
