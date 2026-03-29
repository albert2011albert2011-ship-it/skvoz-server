# Мессенджер "Сквозь"

Приложение для обмена сообщениями, работающее как с интернетом, так и без него через Bluetooth, Wi-Fi Direct и другие P2P-соединения.

## Возможности

- ✅ Работа через интернет (онлайн)
- ✅ Работа через Bluetooth (оффлайн)
- ✅ Работа через Wi-Fi Direct (оффлайн)
- ✅ Автоматическое переключение между режимами
- ✅ Очередь сообщений для отправки при появлении соединения
- ✅ Локальное хранение истории сообщений
- ✅ Статусы доставки и прочтения сообщений
- ✅ Поддержка текстовых сообщений, изображений, файлов и голосовых сообщений

## Архитектура

Проект использует архитектуру BLoC (Business Logic Component) для управления состоянием:

```
lib/
├── main.dart                 # Точка входа
├── models/                   # Модели данных
│   ├── message.dart          # Модель сообщения
│   ├── contact.dart          # Модель контакта
│   └── connection_state.dart # Состояние подключения
├── services/                 # Сервисы для работы с железом
│   ├── bluetooth_service.dart    # Bluetooth
│   ├── wifi_direct_service.dart  # Wi-Fi Direct
│   ├── internet_service.dart     # Интернет
│   └── message_service.dart      # Отправка/получение сообщений
├── blocs/                    # BLoC для управления состоянием
│   ├── connection/           # Управление подключением
│   ├── chat/                 # Управление чатами
│   └── contacts/             # Управление контактами
├── screens/                  # Экраны приложения
│   ├── home_screen.dart      # Главный экран
│   └── chat_screen.dart      # Экран чата
└── widgets/                  # Переиспользуемые виджеты
```

## Установка

1. Установите Flutter SDK (версия 3.0 или выше)
2. Клонируйте репозиторий
3. Выполните `flutter pub get`
4. Запустите проект: `flutter run`

## Настройка для Android

### Разрешения в AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### Минимальная версия SDK

В `android/app/build.gradle.kts`:
```kotlin
minSdk = 21
targetSdk = 34
```

## Настройка для iOS

### Info.plist

Добавьте следующие ключи:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Приложению нужен Bluetooth для обмена сообщениями без интернета</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Приложению нужен Bluetooth для подключения к устройствам</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Приложению нужен доступ к локальной сети для Wi-Fi Direct</string>
```

## Зависимости

- **flutter_bloc** - управление состоянием
- **hive** / **hive_flutter** - локальное хранилище
- **connectivity_plus** - мониторинг подключения к интернету
- **network_info_plus** - информация о сети
- **flutter_bluetooth_serial** - работа с Bluetooth
- **wifi_direct** - работа с Wi-Fi Direct
- **permission_handler** - запрос разрешений
- **uuid** - генерация уникальных идентификаторов

## Как это работает

### Режимы подключения

1. **Интернет** (приоритетный)
   - При наличии интернета сообщения отправляются через сервер
   - Поддерживается синхронизация между устройствами

2. **Bluetooth**
   - Автоматически активируется при отсутствии интернета
   - Поиск устройств в радиусе ~10 метров
   - Прямая передача сообщений между устройствами

3. **Wi-Fi Direct**
   - Активируется если Bluetooth недоступен
   - Более высокая скорость передачи
   - Радиус действия ~50 метров

### Очередь сообщений

Если нет активного подключения, сообщения сохраняются в локальную очередь и автоматически отправляются при появлении соединения.

## Разработка

### Запуск в режиме отладки
```bash
flutter run
```

### Сборка релизной версии
```bash
flutter build apk --release
flutter build ios --release
```

### Тестирование
```bash
flutter test
```

## Лицензия

MIT License

## Контакты

Проект создан для демонстрации возможностей Flutter в области P2P-коммуникаций.
