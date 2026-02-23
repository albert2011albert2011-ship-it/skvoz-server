#!/usr/bin/env python3
"""
🚀 Сервер мессенджера «Сквозь» v0.4.0
Flask + Socket.IO + Telegram Cloud Storage + SQLite
Оптимизировано для Railway.app (HTTPS автоматически)
"""

import os, sys, asyncio, threading, time, sqlite3, secrets, hashlib
from datetime import datetime
from pathlib import Path
from contextlib import contextmanager
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
from telegram import Bot
from loguru import logger
from dotenv import load_dotenv
from werkzeug.middleware.proxy_fix import ProxyFix

load_dotenv()

# ============================================================================
# ⚙️ КОНФИГУРАЦИЯ
# ============================================================================
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', '')
TELEGRAM_CHANNEL_ID = os.getenv('TELEGRAM_CHANNEL_ID', '')
SERVER_HOST = os.getenv('SERVER_HOST', '0.0.0.0')
SERVER_PORT = int(os.getenv('PORT', 5000))  # 🔥 Railway использует PORT
SECRET_KEY = os.getenv('SECRET_KEY', 'skvoz-secret-change-me')
DEBUG = os.getenv('DEBUG', 'false').lower() == 'true'
DB_PATH = os.getenv('DB_PATH', 'skvoz.db')
TEMP_FOLDER = os.getenv('TEMP_FOLDER', 'temp')
MAX_FILE_SIZE = int(os.getenv('MAX_FILE_SIZE', 50 * 1024 * 1024))
FILE_CACHE_TTL = int(os.getenv('FILE_CACHE_TTL', 3600))
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
LOG_FILE = os.getenv('LOG_FILE', 'logs/server.log')

registration_codes = {}

# ============================================================================
# 📝 ЛОГИРОВАНИЕ
# ============================================================================
def setup_logging():
    Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)
    logger.remove()
    logger.add(sys.stdout, level=LOG_LEVEL, format="<green>{time:HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>", colorize=True)
    logger.add(LOG_FILE, level="DEBUG", rotation="10 MB", retention="7 days", compression="zip", format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} - {message}", backtrace=True, diagnose=True)
    logger.add(Path(LOG_FILE).parent / "errors.log", level="ERROR", rotation="5 MB", retention="30 days", compression="zip")
    logger.info(f"📝 Логирование: {LOG_LEVEL} → {LOG_FILE}")
setup_logging()

# ============================================================================
# 🗄️ БАЗА ДАННЫХ
# ============================================================================
@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(f"❌ Ошибка БД: {e}")
        raise
    finally:
        conn.close()

def init_db():
    with get_db() as conn:
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id TEXT, username TEXT UNIQUE NOT NULL, display_name TEXT,
            bio TEXT, main_channel TEXT, avatar_file_id TEXT, cloud_password_hash TEXT,
            balance REAL DEFAULT 0, free_generations INTEGER DEFAULT 3,
            language TEXT DEFAULT 'ru', theme TEXT DEFAULT 'light',
            is_verified INTEGER DEFAULT 0, is_blocked INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP, last_seen TEXT DEFAULT CURRENT_TIMESTAMP
        )''')
        c.execute('''CREATE TABLE IF NOT EXISTS chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT, chat_id TEXT UNIQUE NOT NULL,
            chat_type TEXT CHECK(chat_type IN ('private','group','channel')) DEFAULT 'private',
            title TEXT, avatar_file_id TEXT, is_archived INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )''')
        c.execute('''CREATE TABLE IF NOT EXISTS chat_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT, chat_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL, role TEXT DEFAULT 'member',
            joined_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (chat_id) REFERENCES chats(id),
            FOREIGN KEY (user_id) REFERENCES users(id),
            UNIQUE(chat_id, user_id)
        )''')
        c.execute('''CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, chat_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL, text TEXT, file_type TEXT, file_id TEXT,
            file_name TEXT, file_size INTEGER, telegram_message_id INTEGER,
            reply_to_message_id INTEGER, is_edited INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (chat_id) REFERENCES chats(id),
            FOREIGN KEY (user_id) REFERENCES users(id)
        )''')
        c.execute('''CREATE TABLE IF NOT EXISTS attachments (
            id INTEGER PRIMARY KEY AUTOINCREMENT, message_id INTEGER NOT NULL,
            file_type TEXT NOT NULL, telegram_file_id TEXT NOT NULL,
            original_name TEXT, mime_type TEXT, file_size INTEGER,
            width INTEGER, height INTEGER, duration INTEGER,
            uploaded_at TEXT DEFAULT CURRENT_TIMESTAMP, expires_at TEXT,
            FOREIGN KEY (message_id) REFERENCES messages(id)
        )''')
        c.execute('''CREATE TABLE IF NOT EXISTS user_settings (
            user_id INTEGER PRIMARY KEY, notifications_enabled INTEGER DEFAULT 1,
            sound_enabled INTEGER DEFAULT 1, vibration_enabled INTEGER DEFAULT 1,
            online_status_visible INTEGER DEFAULT 1, last_seen_visible INTEGER DEFAULT 1,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )''')
        c.execute('CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at DESC)')
        c.execute('CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)')
        logger.info("✅ База данных инициализирована")

# ============================================================================
# 🔧 ФУНКЦИИ БД
# ============================================================================
def get_user_by_id(user_id):
    with get_db() as conn:
        c = conn.cursor()
        c.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        row = c.fetchone()
        return dict(row) if row else None

def get_user_chats(user_id):
    with get_db() as conn:
        c = conn.cursor()
        c.execute('''SELECT c.*, 
            (SELECT COUNT(*) FROM messages m WHERE m.chat_id = c.id AND m.is_deleted = 0) as message_count,
            (SELECT text FROM messages m WHERE m.chat_id = c.id AND m.is_deleted = 0 ORDER BY m.created_at DESC LIMIT 1) as last_message_text,
            (SELECT created_at FROM messages m WHERE m.chat_id = c.id AND m.is_deleted = 0 ORDER BY m.created_at DESC LIMIT 1) as last_message_time
            FROM chats c JOIN chat_members cm ON c.id = cm.chat_id
            WHERE cm.user_id = ? AND c.is_archived = 0 ORDER BY last_message_time DESC NULLS LAST''', (user_id,))
        return [dict(row) for row in c.fetchall()]

def get_messages(chat_id, limit=50, offset=0):
    with get_db() as conn:
        c = conn.cursor()
        c.execute('''SELECT m.*, u.username, u.display_name, u.avatar_file_id
            FROM messages m JOIN users u ON m.user_id = u.id
            WHERE m.chat_id = ? AND m.is_deleted = 0 ORDER BY m.created_at DESC LIMIT ? OFFSET ?''',
            (chat_id, limit, offset))
        return [dict(row) for row in c.fetchall()]

def search_users(query, exclude_id=None):
    if len(query) < 2: return []
    with get_db() as conn:
        c = conn.cursor()
        params = (f'%{query}%', f'%{query}%')
        if exclude_id:
            c.execute('SELECT id, username, display_name, avatar_file_id, bio, main_channel FROM users WHERE (username LIKE ? OR display_name LIKE ?) AND id != ? LIMIT 20', (*params, exclude_id))
        else:
            c.execute('SELECT id, username, display_name, avatar_file_id, bio, main_channel FROM users WHERE username LIKE ? OR display_name LIKE ? LIMIT 20', params)
        return [dict(row) for row in c.fetchall()]

def create_chat(user_id, chat_type='private', title=None, member_ids=None):
    with get_db() as conn:
        c = conn.cursor()
        chat_id = f"{chat_type}_{int(time.time())}_{user_id}"
        c.execute('INSERT INTO chats (chat_id, chat_type, title) VALUES (?, ?, ?)', (chat_id, chat_type, title))
        new_id = c.lastrowid
        for mid in set([user_id] + (member_ids or [])):
            c.execute('INSERT OR IGNORE INTO chat_members (chat_id, user_id, role) VALUES (?, ?, ?)', (new_id, mid, 'admin' if mid == user_id else 'member'))
        return new_id

# ============================================================================
# 🤖 TELEGRAM FILE MANAGER
# ============================================================================
class TelegramFileManager:
    def __init__(self, bot_token, channel_id):
        self.bot = Bot(token=bot_token) if bot_token else None
        self.channel_id = channel_id
        self.temp_folder = TEMP_FOLDER
        self.cache_ttl = FILE_CACHE_TTL
        self.file_cache = {}
        os.makedirs(self.temp_folder, exist_ok=True)
        logger.info(f"🤖 Telegram FileManager: канал={channel_id}")
    
    async def upload_file(self, file_path, caption=None):
        if not self.bot: return {'error': 'Telegram not configured'}
        try:
            ext = Path(file_path).suffix.lower()
            if ext in ['.jpg','.jpeg','.png','.webp','.gif']:
                with open(file_path,'rb') as f:
                    msg = await self.bot.send_photo(self.channel_id, photo=f, caption=caption, read_timeout=60)
                    file_id, file_type = msg.photo[-1].file_id, 'image'
            elif ext in ['.mp4','.mov','.webm']:
                with open(file_path,'rb') as f:
                    msg = await self.bot.send_video(self.channel_id, video=f, caption=caption, read_timeout=120)
                    file_id, file_type = msg.video.file_id, 'video'
            elif ext in ['.mp3','.ogg','.wav','.m4a']:
                with open(file_path,'rb') as f:
                    msg = await self.bot.send_audio(self.channel_id, audio=f, caption=caption, read_timeout=60)
                    file_id, file_type = msg.audio.file_id, 'audio'
            else:
                with open(file_path,'rb') as f:
                    msg = await self.bot.send_document(self.channel_id, document=f, caption=caption, read_timeout=60)
                    file_id = msg.document.file_id if msg.document else None
                    file_type = 'document'
            if os.path.exists(file_path): os.remove(file_path)
            logger.info(f"✅ Файл загружен в Telegram: {file_id}")
            return {'file_id': file_id, 'file_type': file_type}
        except Exception as e:
            logger.error(f"❌ Ошибка загрузки: {e}")
            return {'error': str(e)}
    
    async def download_file(self, file_id, file_name=None):
        import time
        if not self.bot: raise Exception("Telegram бот не инициализирован")
        if file_id in self.file_cache:
            path, expires = self.file_cache[file_id]
            if time.time() < expires and os.path.exists(path): return path
            if os.path.exists(path): os.remove(path)
            del self.file_cache[file_id]
        file = await self.bot.get_file(file_id)
        if not file_name: file_name = f"file_{file_id[:12]}{Path(file.file_path).suffix if file.file_path else '.bin'}"
        local_path = os.path.join(self.temp_folder, file_name)
        await file.download_to_drive(local_path)
        self.file_cache[file_id] = (local_path, time.time() + self.cache_ttl)
        logger.info(f"📥 Скачан файл: {file_id}")
        return local_path
    
    def cleanup_cache(self):
        import time
        expired = [fid for fid, (_, exp) in self.file_cache.items() if time.time() >= exp]
        for fid in expired:
            path, _ = self.file_cache.pop(fid)
            if os.path.exists(path):
                os.remove(path)
                logger.debug(f"🧹 Очищен кэш: {path}")

file_manager = None
def init_telegram():
    global file_manager
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHANNEL_ID:
        file_manager = TelegramFileManager(TELEGRAM_BOT_TOKEN, TELEGRAM_CHANNEL_ID)
        logger.info("✅ Telegram FileManager готов")
    else:
        logger.warning("⚠️ Telegram не настроен")

# ============================================================================
# 🌐 FLASK APP + SOCKET.IO
# ============================================================================
logger.info("🚀 Запуск сервера «Сквозь»...")
app = Flask(__name__, static_folder='dist', static_url_path='')
app.config['SECRET_KEY'] = SECRET_KEY

# 🔥 CORS: РАЗРЕШАЕМ ВСЕ ИСТОЧНИКИ
def allow_all_origins(origin):
    return True

CORS(app, 
     origins=allow_all_origins,
     supports_credentials=True,
     methods=['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
     allow_headers=['Content-Type','Authorization','X-User-ID','X-Telegram-ID','Accept','Origin'])

@app.after_request
def add_cors_headers(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-User-ID,X-Telegram-ID,Accept,Origin')
    response.headers.add('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS')
    response.headers.add('Access-Control-Allow-Credentials', 'true')
    return response

app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

socketio = SocketIO(app, cors_allowed_origins=['*'], async_mode='threading', logger=False, engineio_logger=False, ping_timeout=60, ping_interval=25)

init_db()
init_telegram()
connected_users = {}

# ============================================================================
# 🐛 ОТЛАДКА
# ============================================================================
@app.before_request
def log_request_info():
    logger.debug(f"📥 Запрос: {request.method} {request.path}")
    logger.debug(f"   Origin: {request.headers.get('Origin', 'N/A')}")

@app.after_request
def log_response_info(response):
    logger.debug(f"📤 Ответ: {response.status_code} {request.path}")
    return response

# ============================================================================
# 📡 WEBSOCKET
# ============================================================================
@socketio.on('connect')
def on_connect():
    user_id = request.args.get('user_id', 'unknown')
    sid = request.sid
    connected_users[sid] = {'user_id': user_id, 'connected_at': datetime.now().isoformat()}
    logger.info(f"🔌 [+] ПОДКЛЮЧЁН: user_id={user_id}, sid={sid}")
    emit('connected', {'message': 'Connected', 'server_time': datetime.now().isoformat()})

@socketio.on('disconnect')
def on_disconnect():
    sid = request.sid
    user_info = connected_users.pop(sid, {})
    logger.info(f"🔌 [-] ОТКЛЮЧЁН: user_id={user_info.get('user_id')}, sid={sid}")

@socketio.on('join_chat')
def on_join_chat(data):
    chat_id = data.get('chat_id')
    if chat_id:
        join_room(f'chat_{chat_id}')
        emit('user_joined', {'user_id': data.get('user_id')}, room=f'chat_{chat_id}', include_self=False)

@socketio.on('leave_chat')
def on_leave_chat(data):
    if data.get('chat_id'): leave_room(f"chat_{data['chat_id']}")

@socketio.on('send_message')
def on_send_message(data):
    if data.get('chat_id') and data.get('user_id'):
        emit('new_message', {**data, 'sent_at': datetime.now().isoformat()}, room=f"chat_{data['chat_id']}", include_self=False)

@socketio.on('typing')
def on_typing(data):
    if data.get('chat_id'): emit('user_typing', data, room=f"chat_{data['chat_id']}", include_self=False)

@socketio.on('message_read')
def on_message_read(data):
    if data.get('chat_id'): emit('message_read', data, room=f"chat_{data['chat_id']}", include_self=False)

@socketio.on_error_default
def default_error_handler(e): logger.error(f"❌ WebSocket ошибка: {e}")

# ============================================================================
# 🌐 API ENDPOINTS
# ============================================================================
@app.route('/')
def serve_index():
    try: return send_from_directory('dist', 'index.html')
    except: return jsonify({'error': 'Frontend not found'}), 404

@app.route('/<path:path>')
def serve_static(path):
    if path.startswith('api/') or path.startswith('socket.io/'): return None
    try: return send_from_directory('dist', path)
    except: return send_from_directory('dist', 'index.html')

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'timestamp': datetime.now().isoformat(), 'version': '0.4.0', 'database': 'connected', 'telegram': 'connected' if file_manager and file_manager.bot else 'disconnected', 'connected_users': len(connected_users)})

@app.route('/api/test/connection', methods=['GET','POST','OPTIONS'])
def api_test_connection():
    if request.method == 'OPTIONS':
        resp = jsonify({'status': 'ok'})
        resp.headers.add('Access-Control-Allow-Origin', '*')
        resp.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-User-ID,Origin')
        resp.headers.add('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        return resp, 200
    return jsonify({
        'status': 'ok', 'method': request.method, 'path': request.path,
        'origin': request.headers.get('Origin'),
        'server_time': datetime.now().isoformat(),
        'message': '✅ Сервер работает!'
    })

@app.route('/api/auth/check-username', methods=['GET'])
def api_check_username():
    username = request.args.get('username', '').lower().strip()
    if len(username) < 3: return jsonify({'available': False, 'error': 'Минимум 3 символа'}), 400
    with get_db() as conn:
        c = conn.cursor()
        c.execute('SELECT id FROM users WHERE username = ?', (username,))
        return jsonify({'available': not c.fetchone()})

@app.route('/api/auth/register', methods=['POST'])
def api_start_registration():
    data = request.json or {}
    display_name, username = data.get('display_name','').strip(), data.get('username','').lower().strip()
    if not display_name or not username: return jsonify({'error': 'Заполните все поля'}), 400
    if len(username) < 3: return jsonify({'error': 'Username минимум 3 символа'}), 400
    with get_db() as conn:
        c = conn.cursor()
        c.execute('SELECT id FROM users WHERE username = ?', (username,))
        if c.fetchone(): return jsonify({'error': 'Этот username уже занят'}), 409
    telegram_code = secrets.token_hex(4).upper()
    registration_codes[telegram_code] = {'display_name': display_name, 'username': username, 'created_at': time.time()}
    logger.info(f"📝 Регистрация: {username} → код {telegram_code}")
    return jsonify({'success': True, 'user_id': 0, 'telegram_code': telegram_code}), 201

@app.route('/api/auth/complete-register', methods=['POST'])
def api_complete_registration():
    data = request.json or {}
    telegram_code, cloud_password = data.get('telegram_code','').strip().upper(), data.get('cloud_password','')
    if not telegram_code or telegram_code not in registration_codes: return jsonify({'error': 'Неверный код или код истёк'}), 400
    if len(cloud_password) < 6: return jsonify({'error': 'Пароль минимум 6 символов'}), 400
    reg_data = registration_codes[telegram_code]
    if time.time() - reg_data['created_at'] > 600:
        del registration_codes[telegram_code]
        return jsonify({'error': 'Код истёк'}), 400
    password_hash = hashlib.sha256(cloud_password.encode()).hexdigest()
    with get_db() as conn:
        c = conn.cursor()
        c.execute('INSERT INTO users (username, display_name, cloud_password_hash, is_verified) VALUES (?, ?, ?, ?)', (reg_data['username'], reg_data['display_name'], password_hash, 1))
        user_id = c.lastrowid
        c.execute('INSERT INTO user_settings (user_id) VALUES (?)', (user_id,))
        c.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        user = dict(c.fetchone())
    del registration_codes[telegram_code]
    logger.info(f"✅ Регистрация завершена: {reg_data['username']} (ID: {user_id})")
    return jsonify({'success': True, 'user': {k:v for k,v in user.items() if k not in ['cloud_password_hash','is_blocked']}}), 201

@app.route('/api/auth/login', methods=['POST'])
def api_login():
    data = request.json or {}
    username, cloud_password = data.get('username','').lower().strip(), data.get('cloud_password','')
    if not username or not cloud_password: return jsonify({'error': 'Заполните все поля'}), 400
    password_hash = hashlib.sha256(cloud_password.encode()).hexdigest()
    with get_db() as conn:
        c = conn.cursor()
        c.execute('SELECT * FROM users WHERE username = ? AND cloud_password_hash = ?', (username, password_hash))
        user = c.fetchone()
        if not user: return jsonify({'error': 'Неверный username или пароль'}), 401
        c.execute('UPDATE users SET last_seen = CURRENT_TIMESTAMP WHERE id = ?', (user['id'],))
        return jsonify({'success': True, 'user': {k:v for k,v in dict(user).items() if k not in ['cloud_password_hash','is_blocked']}})

@app.route('/api/auth/logout', methods=['POST'])
def api_logout(): return jsonify({'success': True})

@app.route('/api/user/<int:user_id>', methods=['GET'])
def api_get_user(user_id):
    user = get_user_by_id(user_id)
    if not user: return jsonify({'error': 'User not found'}), 404
    return jsonify({k:v for k,v in user.items() if k not in ['cloud_password_hash','is_blocked']})

@app.route('/api/user/<int:user_id>/profile', methods=['PATCH'])
def api_update_profile(user_id):
    data = request.json or {}
    with get_db() as conn:
        c = conn.cursor()
        for field in ['display_name', 'bio', 'main_channel']:
            if field in data: c.execute(f'UPDATE users SET {field} = ? WHERE id = ?', (data[field], user_id))
        c.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        user = dict(c.fetchone())
    return jsonify({'success': True, 'user': {k:v for k,v in user.items() if k not in ['cloud_password_hash','is_blocked']}})

@app.route('/api/user/<int:user_id>/password', methods=['PATCH'])
def api_change_password(user_id):
    data = request.json or {}
    old_pwd, new_pwd = data.get('old_password',''), data.get('new_password','')
    if len(new_pwd) < 6: return jsonify({'error': 'Пароль минимум 6 символов'}), 400
    old_hash = hashlib.sha256(old_pwd.encode()).hexdigest()
    with get_db() as conn:
        c = conn.cursor()
        c.execute('SELECT cloud_password_hash FROM users WHERE id = ?', (user_id,))
        user = c.fetchone()
        if not user or user['cloud_password_hash'] != old_hash: return jsonify({'error': 'Неверный старый пароль'}), 401
        new_hash = hashlib.sha256(new_pwd.encode()).hexdigest()
        c.execute('UPDATE users SET cloud_password_hash = ? WHERE id = ?', (new_hash, user_id))
    return jsonify({'success': True})

@app.route('/api/user/<int:user_id>/avatar', methods=['POST'])
def api_upload_avatar(user_id):
    if 'avatar' not in request.files: return jsonify({'error': 'Нет файла'}), 400
    file = request.files['avatar']
    if not file.filename: return jsonify({'error': 'Пустой файл'}), 400
    temp_path = os.path.join(TEMP_FOLDER, f"avatar_{user_id}_{int(time.time())}.jpg")
    file.save(temp_path)
    if file_manager and file_manager.bot:
        result = asyncio.run(file_manager.upload_file(temp_path, caption=f'Avatar for user {user_id}'))
        if 'file_id' in result:
            with get_db() as conn:
                c = conn.cursor()
                c.execute('UPDATE users SET avatar_file_id = ? WHERE id = ?', (result['file_id'], user_id))
            return jsonify({'success': True, 'avatar_file_id': result['file_id']})
    return jsonify({'error': 'Ошибка загрузки'}), 500

@app.route('/api/chats', methods=['GET'])
def api_get_chats():
    user_id = request.args.get('user_id', type=int)
    if not user_id: return jsonify({'error': 'user_id required'}), 400
    return jsonify(get_user_chats(user_id))

@app.route('/api/chats', methods=['POST'])
def api_create_chat():
    data = request.json or {}
    user_id = data.get('user_id')
    if not user_id: return jsonify({'error': 'user_id required'}), 400
    chat_id = create_chat(user_id=user_id, chat_type=data.get('type','private'), title=data.get('title'), member_ids=data.get('member_ids',[]))
    return jsonify({'success': True, 'chat_id': chat_id}), 201

@app.route('/api/chats/<int:chat_id>/messages', methods=['GET','POST'])
def api_messages(chat_id):
    if request.method == 'POST':
        data = request.json or {}
        user_id, text = data.get('user_id'), data.get('text')
        if not user_id: return jsonify({'error': 'user_id required'}), 400
        file_id, file_type, file_name, file_size = None, None, None, None
        if 'file' in request.files:
            file_obj = request.files['file']
            if file_obj and file_obj.filename:
                temp_path = os.path.join(TEMP_FOLDER, f"{int(time.time())}_{file_obj.filename}")
                file_obj.save(temp_path)
                if file_manager and file_manager.bot:
                    result = asyncio.run(file_manager.upload_file(temp_path, caption=text))
                    if 'file_id' in result: file_id, file_type = result['file_id'], result['file_type']
                file_name = file_obj.filename
                if os.path.exists(temp_path): file_size = os.path.getsize(temp_path)
        with get_db() as conn:
            c = conn.cursor()
            c.execute('INSERT INTO messages (chat_id, user_id, text, file_type, file_id, file_name, file_size) VALUES (?, ?, ?, ?, ?, ?, ?)', (chat_id, user_id, text, file_type, file_id, file_name, file_size))
            msg_id = c.lastrowid
        socketio.emit('new_message', {'id': msg_id, 'chat_id': chat_id, 'user_id': user_id, 'text': text, 'file_id': file_id, 'file_type': file_type, 'created_at': datetime.now().isoformat()}, room=f'chat_{chat_id}')
        logger.info(f"💬 Сообщение #{msg_id} в чате #{chat_id}")
        return jsonify({'success': True, 'message_id': msg_id}), 201
    limit, offset = request.args.get('limit',50,type=int), request.args.get('offset',0,type=int)
    return jsonify(get_messages(chat_id, limit, offset))

@app.route('/api/users/search', methods=['GET'])
def api_search_users():
    query, exclude = request.args.get('q',''), request.args.get('exclude_id', type=int)
    return jsonify(search_users(query, exclude_id=exclude))

@app.route('/api/files/<file_id>', methods=['GET'])
def api_serve_file(file_id):
    if not file_manager or not file_manager.bot: return jsonify({'error': 'Telegram not configured'}), 503
    try:
        local_path = asyncio.run(file_manager.download_file(file_id))
        return send_from_directory(TEMP_FOLDER, os.path.basename(local_path))
    except Exception as e:
        logger.error(f"❌ Ошибка отдачи файла {file_id}: {e}")
        return jsonify({'error': 'File not found'}), 404

# ============================================================================
# 🧹 ФОНОВЫЕ ЗАДАЧИ
# ============================================================================
def periodic_cleanup():
    while True:
        time.sleep(300)
        try:
            for f in Path(TEMP_FOLDER).iterdir():
                if f.is_file() and time.time() - f.stat().st_mtime > FILE_CACHE_TTL + 3600:
                    f.unlink()
            if file_manager: file_manager.cleanup_cache()
        except Exception as e: logger.error(f"❌ Ошибка при очистке: {e}")

threading.Thread(target=periodic_cleanup, daemon=True).start()

# ============================================================================
# 🚀 ЗАПУСК (ОПТИМИЗИРОВАНО ДЛЯ RAILWAY)
# ============================================================================
if __name__ == '__main__':
    # 🔥 Railway использует переменную PORT
    port = int(os.environ.get('PORT', SERVER_PORT))
    logger.info(f"🌐 Сервер слушает: http://0.0.0.0:{port}")
    logger.info(f"🔌 WebSocket: ws://0.0.0.0:{port}/socket.io")
    socketio.run(app, host='0.0.0.0', port=port, debug=DEBUG, allow_unsafe_werkzeug=True)