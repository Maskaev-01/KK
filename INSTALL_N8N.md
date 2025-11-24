# Инструкция по установке n8n на Linux сервере через Docker

## 📋 Содержание
1. [Требования](#требования)
2. [Установка Docker и Docker Compose](#установка-docker-и-docker-compose)
3. [Настройка n8n](#настройка-n8n)
4. [Запуск n8n](#запуск-n8n)
5. [Настройка как системного сервиса](#настройка-как-системного-сервиса)
6. [Настройка обратного прокси (Nginx)](#настройка-обратного-прокси-nginx)
7. [Безопасность](#безопасность)
8. [Резервное копирование](#резервное-копирование)
9. [Устранение неполадок](#устранение-неполадок)

---

## Требования

- Linux сервер (Ubuntu 20.04+, Debian 11+, CentOS 8+)
- Минимум 2GB RAM
- Минимум 10GB свободного места на диске
- Root доступ или пользователь с sudo правами
- Открытый порт 5678 (или другой, если используете обратный прокси)

---

## Установка Docker и Docker Compose

### Ubuntu/Debian

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка зависимостей
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Добавление официального GPG ключа Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавление репозитория Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Проверка установки
docker --version
docker compose version

# Добавление пользователя в группу docker (чтобы не использовать sudo)
sudo usermod -aG docker $USER
newgrp docker
```

### CentOS/RHEL

```bash
# Установка зависимостей
sudo yum install -y yum-utils

# Добавление репозитория Docker
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Установка Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker
```

---

## Настройка n8n

### 1. Создание директории для проекта

```bash
# Создаем директорию
sudo mkdir -p /opt/n8n
cd /opt/n8n

# Устанавливаем права доступа
sudo chown -R $USER:$USER /opt/n8n
```

### 2. Создание docker-compose.yaml

Скопируйте файл `docker-compose.yaml` в директорию `/opt/n8n/`:

```bash
# Если файл уже создан, просто скопируйте его
cp /path/to/docker-compose.yaml /opt/n8n/
```

### 3. Создание файла .env

```bash
cd /opt/n8n
nano .env
```

Добавьте следующие переменные (замените на свои значения):

```env
# Базовые учетные данные
N8N_USER=admin
N8N_PASSWORD=your_secure_password_here

# Хост (если используете домен)
N8N_HOST=your-domain.com
N8N_PROTOCOL=https

# URL для webhooks
WEBHOOK_URL=https://your-domain.com/

# Ключ шифрования (сгенерируйте случайную строку)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
```

**Важно:** Сгенерируйте безопасный пароль и ключ шифрования:

```bash
# Генерация случайного пароля
openssl rand -base64 24

# Генерация ключа шифрования
openssl rand -base64 32
```

### 4. Настройка прав доступа

```bash
# Устанавливаем правильные права на файлы
chmod 600 /opt/n8n/.env
chmod 644 /opt/n8n/docker-compose.yaml
```

---

## Запуск n8n

### Первый запуск

```bash
cd /opt/n8n

# Запуск в фоновом режиме
docker compose up -d

# Просмотр логов
docker compose logs -f

# Проверка статуса
docker compose ps
```

### Управление контейнером

```bash
# Остановка
docker compose down

# Перезапуск
docker compose restart

# Обновление до последней версии
docker compose pull
docker compose up -d

# Просмотр логов
docker compose logs -f n8n
```

### Доступ к n8n

После запуска n8n будет доступен по адресу:
- **Локально:** http://localhost:5678
- **По сети:** http://your-server-ip:5678

Войдите используя учетные данные из файла `.env`.

---

## Настройка как системного сервиса

### 1. Создание systemd сервиса

```bash
# Копируем файл сервиса
sudo cp n8n.service /etc/systemd/system/

# Или создаем вручную
sudo nano /etc/systemd/system/n8n.service
```

Содержимое файла `/etc/systemd/system/n8n.service`:

```ini
[Unit]
Description=n8n workflow automation
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/n8n
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Примечание:** Если используете `docker-compose` (старая версия), замените `/usr/bin/docker compose` на `/usr/local/bin/docker-compose`.

### 2. Активация сервиса

```bash
# Перезагрузка systemd
sudo systemctl daemon-reload

# Включение автозапуска
sudo systemctl enable n8n.service

# Запуск сервиса
sudo systemctl start n8n.service

# Проверка статуса
sudo systemctl status n8n.service

# Просмотр логов
sudo journalctl -u n8n.service -f
```

### 3. Управление сервисом

```bash
# Запуск
sudo systemctl start n8n

# Остановка
sudo systemctl stop n8n

# Перезапуск
sudo systemctl restart n8n

# Статус
sudo systemctl status n8n
```

---

## Настройка обратного прокси (Nginx)

### 1. Установка Nginx

```bash
sudo apt install -y nginx
```

### 2. Создание конфигурации

```bash
sudo nano /etc/nginx/sites-available/n8n
```

Добавьте следующую конфигурацию:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Редирект на HTTPS (опционально)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL сертификаты (используйте Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Увеличение размера тела запроса для больших workflows
    client_max_body_size 50M;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_cache_bypass $http_upgrade;
        
        # Таймауты для long-running workflows
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

### 3. Активация конфигурации

```bash
# Создание символической ссылки
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Проверка конфигурации
sudo nginx -t

# Перезагрузка Nginx
sudo systemctl reload nginx
```

### 4. Установка SSL сертификата (Let's Encrypt)

```bash
# Установка Certbot
sudo apt install -y certbot python3-certbot-nginx

# Получение сертификата
sudo certbot --nginx -d your-domain.com

# Автоматическое обновление
sudo certbot renew --dry-run
```

### 5. Обновление .env файла

После настройки Nginx обновите файл `.env`:

```env
N8N_HOST=your-domain.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://your-domain.com/
```

И перезапустите контейнер:

```bash
cd /opt/n8n
docker compose restart
```

---

## Безопасность

### 1. Настройка файрвола

```bash
# Установка UFW (если не установлен)
sudo apt install -y ufw

# Разрешение SSH
sudo ufw allow 22/tcp

# Разрешение HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Блокировка прямого доступа к порту 5678 (если используете Nginx)
sudo ufw deny 5678/tcp

# Включение файрвола
sudo ufw enable
sudo ufw status
```

### 2. Регулярное обновление

```bash
# Создание скрипта обновления
nano /opt/n8n/update.sh
```

```bash
#!/bin/bash
cd /opt/n8n
docker compose pull
docker compose up -d
docker system prune -f
```

```bash
chmod +x /opt/n8n/update.sh
```

### 3. Ограничение доступа по IP (опционально)

В Nginx конфигурации добавьте:

```nginx
# Разрешить доступ только с определенных IP
allow 192.168.1.0/24;
allow 10.0.0.0/8;
deny all;
```

---

## Резервное копирование

### 1. Создание скрипта резервного копирования

```bash
nano /opt/n8n/backup.sh
```

```bash
#!/bin/bash

BACKUP_DIR="/opt/n8n/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"

# Создание директории для бэкапов
mkdir -p $BACKUP_DIR

# Остановка контейнера (опционально, для консистентности)
cd /opt/n8n
docker compose stop n8n

# Создание бэкапа volume
docker run --rm \
  -v n8n_n8n_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/n8n_backup_$DATE.tar.gz -C /data .

# Запуск контейнера
docker compose start n8n

# Удаление старых бэкапов (старше 30 дней)
find $BACKUP_DIR -name "n8n_backup_*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE"
```

```bash
chmod +x /opt/n8n/backup.sh
```

### 2. Настройка автоматического резервного копирования

```bash
# Добавление в crontab
crontab -e
```

Добавьте строку для ежедневного бэкапа в 2:00 ночи:

```
0 2 * * * /opt/n8n/backup.sh >> /opt/n8n/backup.log 2>&1
```

### 3. Восстановление из бэкапа

```bash
# Остановка контейнера
cd /opt/n8n
docker compose down

# Восстановление данных
docker run --rm \
  -v n8n_n8n_data:/data \
  -v /opt/n8n/backups:/backup \
  alpine sh -c "cd /data && tar xzf /backup/n8n_backup_YYYYMMDD_HHMMSS.tar.gz"

# Запуск контейнера
docker compose up -d
```

---

## Устранение неполадок

### Проблема: Контейнер не запускается

```bash
# Просмотр логов
docker compose logs n8n

# Проверка статуса
docker compose ps

# Проверка использования ресурсов
docker stats
```

### Проблема: Не могу войти в систему

```bash
# Проверка переменных окружения
docker compose exec n8n env | grep N8N_BASIC_AUTH

# Пересоздание контейнера
docker compose down
docker compose up -d
```

### Проблема: Webhooks не работают

1. Проверьте `WEBHOOK_URL` в `.env`
2. Убедитесь, что порт открыт в файрволе
3. Проверьте настройки Nginx (если используется)

### Проблема: Недостаточно места на диске

```bash
# Очистка неиспользуемых Docker ресурсов
docker system prune -a --volumes

# Проверка использования диска
df -h
du -sh /var/lib/docker/volumes/*
```

### Проблема: Высокое использование памяти

```bash
# Ограничение памяти в docker-compose.yaml
services:
  n8n:
    mem_limit: 2g
    mem_reservation: 1g
```

---

## Полезные команды

```bash
# Просмотр всех workflows
docker compose exec n8n ls -la /home/node/.n8n/

# Доступ к shell контейнера
docker compose exec n8n sh

# Экспорт переменных окружения
docker compose config

# Проверка здоровья контейнера
docker compose ps
docker inspect n8n | grep Health
```

---

## Дополнительные настройки

### Использование PostgreSQL вместо SQLite

Обновите `docker-compose.yaml`:

```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: your_password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    # ... существующие настройки ...
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=your_password
    depends_on:
      - postgres

volumes:
  postgres_data:
```

---

## Поддержка

- Официальная документация: https://docs.n8n.io/
- GitHub: https://github.com/n8n-io/n8n
- Community Forum: https://community.n8n.io/

---

**Готово!** Теперь ваш n8n запущен и настроен как системный сервис на Linux сервере.
