import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'bluetooth_service.dart';
import 'wifi_direct_service.dart';
import 'internet_service.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  final BluetoothService _bluetoothService = BluetoothService();
  final WifiDirectService _wifiDirectService = WifiDirectService();
  final InternetService _internetService = InternetService();

  ConnectionType _currentConnectionType = ConnectionType.offline;
  bool _isInitialized = false;

  final _connectionTypeController = StreamController<ConnectionType>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _transferProgressController = StreamController<TransferProgress>.broadcast();

  Stream<ConnectionType> get connectionTypeStream => _connectionTypeController.stream;
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<TransferProgress> get transferProgressStream => _transferProgressController.stream;

  ConnectionType get currentConnectionType => _currentConnectionType;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Подписываемся на изменения подключения
    Connectivity().onConnectivityChanged.listen(_updateConnectionType);

    // Подписываемся на сообщения от всех сервисов
    _bluetoothService.messageStream.listen(_messageController.add);
    _wifiDirectService.messageStream.listen(_messageController.add);
    _internetService.messageStream.listen(_messageController.add);

    // Подписываемся на прогресс передачи файлов
    _bluetoothService.transferProgressStream.listen(_transferProgressController.add);
    _wifiDirectService.transferProgressStream.listen(_transferProgressController.add);
    _internetService.transferProgressStream.listen(_transferProgressController.add);

    await _updateConnectionType(await Connectivity().checkConnectivity());
    _isInitialized = true;
  }

  Future<void> _updateConnectionType(ConnectivityResult result) async {
    ConnectionType newType;

    if (result == ConnectivityResult.wifi || result == ConnectivityResult.ethernet) {
      // Проверяем доступность интернета
      try {
        // Здесь можно добавить проверку пинга до сервера
        newType = ConnectionType.internet;
      } catch (e) {
        newType = ConnectionType.wifiDirect;
      }
    } else if (result == ConnectivityResult.bluetooth) {
      newType = ConnectionType.bluetooth;
    } else if (result == ConnectivityResult.none) {
      // Проверяем локальные подключения
      if (_wifiDirectService.isConnected) {
        newType = ConnectionType.wifiDirect;
      } else if (_bluetoothService.isConnected) {
        newType = ConnectionType.bluetooth;
      } else {
        newType = ConnectionType.offline;
      }
    } else {
      newType = ConnectionType.offline;
    }

    if (newType != _currentConnectionType) {
      _currentConnectionType = newType;
      _connectionTypeController.add(newType);
      print('Тип подключения изменен на: $newType');
    }
  }

  // Bluetooth методы
  Future<void> startBluetoothDiscovery({Duration duration = const Duration(seconds: 10)}) async {
    await _bluetoothService.startDiscovery(duration: duration);
  }

  Future<bool> connectToBluetoothDevice(String address) async {
    final success = await _bluetoothService.connect(address);
    if (success) {
      _currentConnectionType = ConnectionType.bluetooth;
      _connectionTypeController.add(ConnectionType.bluetooth);
    }
    return success;
  }

  // Wi-Fi Direct методы
  Future<void> startWifiDirectServer({int port = 8080}) async {
    await _wifiDirectService.startServer(port: port);
    _currentConnectionType = ConnectionType.wifiDirect;
    _connectionTypeController.add(ConnectionType.wifiDirect);
  }

  Future<void> connectToWifiDirectServer(String host, {int port = 8080}) async {
    await _wifiDirectService.connectToServer(host, port: port);
    _currentConnectionType = ConnectionType.wifiDirect;
    _connectionTypeController.add(ConnectionType.wifiDirect);
  }

  // Интернет методы
  Future<void> connectToInternet(String serverUrl, String userId) async {
    await _internetService.connect(serverUrl, userId);
    _currentConnectionType = ConnectionType.internet;
    _connectionTypeController.add(ConnectionType.internet);
  }

  // Отправка сообщений с автоматическим выбором метода
  Future<void> sendMessage(ChatMessage message) async {
    switch (_currentConnectionType) {
      case ConnectionType.bluetooth:
        await _bluetoothService.sendMessage(message);
        break;
      case ConnectionType.wifiDirect:
        await _wifiDirectService.sendMessage(message);
        break;
      case ConnectionType.internet:
        await _internetService.sendMessage(message);
        break;
      case ConnectionType.offline:
        throw Exception('Нет доступного подключения для отправки сообщения');
    }
  }

  // Отправка файлов с автоматическим выбором метода
  Future<void> sendFile(String filePath, String receiverId, String senderId) async {
    switch (_currentConnectionType) {
      case ConnectionType.bluetooth:
        await _bluetoothService.sendFile(filePath, receiverId, senderId);
        break;
      case ConnectionType.wifiDirect:
        await _wifiDirectService.sendFile(filePath, receiverId, senderId);
        break;
      case ConnectionType.internet:
        await _internetService.sendFile(filePath, receiverId, senderId);
        break;
      case ConnectionType.offline:
        throw Exception('Нет доступного подключения для отправки файла');
    }
  }

  // Получение текущего статуса подключения
  bool get isBluetoothConnected => _bluetoothService.isConnected;
  bool get isWifiDirectConnected => _wifiDirectService.isConnected;
  bool get isInternetConnected => _internetService.isConnected;

  String get connectionStatus {
    switch (_currentConnectionType) {
      case ConnectionType.bluetooth:
        return 'Bluetooth: ${_bluetoothService.isConnected ? "Подключено" : "Отключено"}';
      case ConnectionType.wifiDirect:
        return 'Wi-Fi Direct: ${_wifiDirectService.isConnected ? "Подключено" : "Отключено"}';
      case ConnectionType.internet:
        return 'Интернет: ${_internetService.isConnected ? "Подключено" : "Отключено"}';
      case ConnectionType.offline:
        return 'Оффлайн';
    }
  }

  // Отключение
  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    await _wifiDirectService.disconnect();
    await _internetService.disconnect();
    _currentConnectionType = ConnectionType.offline;
    _connectionTypeController.add(ConnectionType.offline);
  }

  void dispose() {
    _connectionTypeController.close();
    _messageController.close();
    _transferProgressController.close();
    _bluetoothService.dispose();
    _wifiDirectService.dispose();
    _internetService.dispose();
  }
}
