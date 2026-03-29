# Анализатор Android

## Настройки

### Минимальная версия SDK
minSdkVersion 21

### Целевая версия SDK
targetSdkVersion 34

### Разрешения
- INTERNET
- ACCESS_NETWORK_STATE
- BLUETOOTH
- BLUETOOTH_ADMIN
- BLUETOOTH_CONNECT
- BLUETOOTH_SCAN
- ACCESS_WIFI_STATE
- CHANGE_WIFI_STATE
- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION
- READ_EXTERNAL_STORAGE
- WRITE_EXTERNAL_STORAGE

## Конфигурация ProGuard
```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive
-keep class com.hivemq.** { *; }
-dontwarn com.hivemq.**

# Bluetooth
-keep class com.philips.bluetooth.** { *; }
-dontwarn com.philips.bluetooth.**
```
