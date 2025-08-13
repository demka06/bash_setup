#!/bin/bash

PACKAGES=(ufw nano lsof pwgen fail2ban clamav clamav-daemon)
SERVICES=(clamav-freshclam clamav-daemon)

# ===== ПРОВЕРКА ПРАВ =====
if [[ $EUID -ne 0 ]]; then
    echo "Запусти скрипт с sudo!"
    exit 1
fi

# ===== УСТАНОВЛЕНИЕ ПЕРЕМЕННЫХ ОКРУЖЕНИЯ =====
export EDITOR=nano

# ===== ПОЛУЧЕНИЕ SSH ПОРТА =====
read -rp "Введите SSH порт (по умолчанию 49456): " SSH_PORT
SSH_PORT=$(echo "$SSH_PORT" | xargs)
SSH_PORT=${SSH_PORT:-49456}

while ss -tuln | grep -E -q ":$SSH_PORT(\s|$)"; do
    echo "Порт $SSH_PORT уже занят. Выберите другой порт"
    read -rp "Введите SSH порт (по умолчанию 49456): " SSH_PORT
    SSH_PORT=$(echo "$SSH_PORT" | xargs)
    SSH_PORT=${SSH_PORT:-49456}
done

# ===== ПОЛУЧЕНИЕ ИМЕНИ ПОЛЬЗОВАТЕЛЯ =====
read -rp "Введите имя нового пользователя: " USER_NAME
USER_NAME=$(echo "$USER_NAME" | xargs)
while id "$USER_NAME" &>/dev/null || [[ -z "$USER_NAME" ]]; do
    read -rp "Пользователь уже существует или имя пустое. Введите другое имя: " USER_NAME
    USER_NAME=$(echo "$USER_NAME" | xargs)
done

# ===== ГЕНЕРАЦИЯ ПАРОЛЯ =====
USER_PASS=$(pwgen 32 1)

# ===== ПРОВЕРКА =====
echo
echo "===== Данные доступа ====="
echo "Пользователь: $USER_NAME"
echo "Пароль: $USER_PASS"
echo "SSH-порт: $SSH_PORT"
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

# ===== ПОЛУЧЕНИЕ SSH КЛЮЧА =====
read -rp "Вставьте публичный ключ (ssh-ed25519...): " PUB_KEY
while [[ ! "$PUB_KEY" =~ ^ssh- ]]; do
    read -rp "Ключ должен начинаться с ssh-. Вставьте снова: " PUB_KEY
done

# ===== ОБНОВЛЕНИЕ СИСТЕМЫ =====
sudo apt-get update
if ! apt-get -s upgrade | grep -q "0 upgraded"; then
    sudo sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a  apt-get full-upgrade -y
fi

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y "$pkg"
    fi
done

curl -fsSL https://get.docker.com | sh

# ===== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ С ПАРОЛЕМ И SUDO =====
sudo adduser --disabled-password --gecos "" "$USER_NAME"
sudo usermod -aG sudo "$USER_NAME"
echo "$USER_NAME:$USER_PASS" | sudo chpasswd

# ===== СОЗДАНИЕ .ssh И ДОБАВЛЕНИЕ ПУБЛИЧНОГО КЛЮЧА =====
# Создание папки .ssh
sudo -u "$USER_NAME" mkdir -p /home/"$USER_NAME"/.ssh
# Установка прав и владельца на папку .ssh
sudo chmod 700 /home/"$USER_NAME"/.ssh
sudo chown -R "$USER_NAME:$USER_NAME" /home/"$USER_NAME"/.ssh
# Добавление ключа
echo "$PUB_KEY" | sudo tee /home/"$USER_NAME"/.ssh/authorized_keys > /dev/null
# Установка прав и владельца на authorized_keys
sudo chmod 600 /home/"$USER_NAME"/.ssh/authorized_keys
sudo chown "$USER_NAME:$USER_NAME" /home/"$USER_NAME"/.ssh/authorized_keys


# ===== ОТКРЫТИЕ ПОРТА ДО РЕДАКТИРОВАНИЯ SSH =====
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$SSH_PORT"/tcp
sudo ufw --force enable

# ===== РЕЗЕРВНАЯ КОПИЯ SSHD_CONFIG =====
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# ===== РЕДАКТИРОВАНИЕ SSHD_CONFIG =====
sudo sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i 's@^#\?AuthorizedKeysFile.*@AuthorizedKeysFile .ssh/authorized_keys@' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# ===== ПЕРЕЗАПУСК SSH =====
sudo systemctl restart ssh

# ===== ОБНОВЛЕНИЕ БАЗЫ ДАННЫХ ClamAV =====
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam
# ОСТАЛЬНОЕ ПАТОМ

# ===== ПРОВЕРКА РАБОТЫ СЕРВИСОВ =====

for srv in "${SERVICES[@]}"; do
    if [ "$(systemctl is-active "$srv")" != "active" ]; then
        sudo systemctl start "$srv"
    fi
done