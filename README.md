# 🚀 Сквозь — Мессенджер нового поколения

Серверная часть мессенджера «Сквозь» на Flask + Socket.IO

## 🌐 Развёртывание на Railway

1. Зарегистрируйся на https://railway.app
2. Нажми "New Project" → "Deploy from GitHub repo"
3. Выбери этот репозиторий
4. Добавь переменные окружения (см. `.env.example`)
5. Railway автоматически задеплоит!

## 🔧 Переменные окружения

| Переменная | Описание |
|------------|----------|
| `TELEGRAM_BOT_TOKEN` | Токен бота от @BotFather |
| `TELEGRAM_CHANNEL_ID` | ID канала для хранения файлов |
| `SECRET_KEY` | Секретный ключ для сессий |
| `PORT` | Порт (Railway устанавливает автоматически) |
| `DEBUG` | Режим отладки (true/false) |

## 📡 API Endpoints

- `GET /api/health` — Проверка работоспособности
- `GET /api/test/connection` — Тест подключения
- `POST /api/auth/register` — Регистрация
- `POST /api/auth/login` — Вход
- `GET /api/chats?user_id=X` — Список чатов
- `POST /api/chats` — Создать чат
- `GET /api/chats/{id}/messages` — Сообщения чата
- `POST /api/chats/{id}/messages` — Отправить сообщение

## 🔌 WebSocket

Подключение: `wss://your-railway-url.up.railway.app/socket.io`

События:
- `connect` — Подключение
- `disconnect` — Отключение
- `join_chat` — Войти в чат
- `send_message` — Отправить сообщение
- `typing` — Пользователь печатает
- `message_read` — Сообщение прочитано

## 📄 Лицензия

MIT License