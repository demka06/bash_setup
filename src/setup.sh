#!/bin/bash

PACKAGES=(ufw nano lsof pwgen fail2ban clamav clamav-daemon git)
SERVICES=(clamav-freshclam clamav-daemon)

CLAMAV_QUARANTINE_DIR="/quarantine"
CLAMAV_SERVICE_FILE="/etc/systemd/system/clamonacc.service"
CLAMAV_LOG_FILE="/var/log/clamonacc.log"

FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"

CRON_JOB="0 0 * * * apt update && apt -y upgrade >> /var/log/auto-update.log 2>&1"

# ===== ПРОВЕРКА ПРАВ =====
if [[ $EUID -ne 0 ]]; then
    echo "Запусти скрипт с sudo!"
    exit 1
fi

# ===== СОЗДАНИЕ КАРАНТИННОЙ ПАПКИ =====
if [ ! -d "$CLAMAV_QUARANTINE_DIR" ]; then
    mkdir -p "$CLAMAV_QUARANTINE_DIR"
    chmod 750 "$CLAMAV_QUARANTINE_DIR"
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
apt-get update
if ! apt-get -s upgrade | grep -q "0 upgraded"; then
    DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a  apt-get full-upgrade -y
fi

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y "$pkg"
    fi
done

curl -fsSL https://get.docker.com | sh

# ===== АВТОМАТИЧЕСКОЕ ОБНОВЛЕНИЕ ПАКЕТОВ ПО НОЧАМ =====
# Проверяем, есть ли уже такая задача
if ! crontab -l | grep -Fq "$CRON_JOB"; then
    # Добавляем задачу в crontab root
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi
# ===== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ С ПАРОЛЕМ И SUDO =====
USER_PASS=$(pwgen 32 1)

adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG sudo "$USER_NAME"
echo "$USER_NAME:$USER_PASS" | chpasswd

# ===== СОЗДАНИЕ .ssh И ДОБАВЛЕНИЕ ПУБЛИЧНОГО КЛЮЧА =====
# Создание папки .ssh
sudo -u "$USER_NAME" mkdir -p /home/"$USER_NAME"/.ssh
# Установка прав и владельца на папку .ssh
chmod 700 /home/"$USER_NAME"/.ssh
chown -R "$USER_NAME:$USER_NAME" /home/"$USER_NAME"/.ssh
# Добавление ключа
echo "$PUB_KEY" | tee /home/"$USER_NAME"/.ssh/authorized_keys > /dev/null
# Установка прав и владельца на authorized_keys
chmod 600 /home/"$USER_NAME"/.ssh/authorized_keys
chown "$USER_NAME:$USER_NAME" /home/"$USER_NAME"/.ssh/authorized_keys


# ===== ОТКРЫТИЕ ПОРТА ДО РЕДАКТИРОВАНИЯ SSH =====
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
ufw --force enable

# ===== РЕЗЕРВНАЯ КОПИЯ SSHD_CONFIG =====
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# ===== РЕДАКТИРОВАНИЕ SSHD_CONFIG =====
sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i 's@^#\?AuthorizedKeysFile.*@AuthorizedKeysFile .ssh/authorized_keys@' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# ===== ПЕРЕЗАПУСК SSH =====
systemctl restart ssh

# ===== ОБНОВЛЕНИЕ БАЗЫ ДАННЫХ ClamAV =====
systemctl stop clamav-freshclam
freshclam
systemctl enable clamav-freshclam

# ===== РАБОТА ClamAV В ФОНЕ =====
tee "$CLAMAV_SERVICE_FILE" > /dev/null <<EOL
[Unit]
Description=ClamAV On-Access Scanner
After=clamav-daemon.service

[Service]
ExecStart=/usr/bin/clamonacc --fdpass --log=$CLAMAV_LOG_FILE --move=$CLAMAV_QUARANTINE_DIR \\
    --exclude-dir=/proc --exclude-dir=/sys --exclude-dir=/dev --include-dir=/run --include-dir=/home
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable --now clamonacc

echo "Установка завершена!"
echo "Лог работы: $CLAMAV_LOG_FILE"
echo "Карантин: $CLAMAV_QUARANTINE_DIR"

# ===== НАСТРОЙКА FAIL2BAN =====
tee "$FAIL2BAN_CONFIG" > /dev/null <<EOL
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = "$SSH_PORT"
filter = sshd
logpath = /var/log/auth.log

# Защита Nginx (если установлен)
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
EOL

systemctl enable --now fail2ban
echo "Fail2Ban установлен и запущен!"
echo "Конфиг: $FAIL2BAN_CONFIG"

# ===== ПРОВЕРКА РАБОТЫ СЕРВИСОВ =====
for srv in "${SERVICES[@]}"; do
    if [ "$(systemctl is-active "$srv")" != "active" ]; then
        systemctl enable --now "$srv"
    fi
done
