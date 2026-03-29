import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';
import 'dart:convert';

class BluetoothService {
  bool _isInitialized = false;
  bool _isEnabled = false;
  List<BluetoothDevice> _availableDevices = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _discoverySubscription;
  
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  List<BluetoothDevice> get availableDevices => _availableDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  Future<void> initialize() async {
    try {
      _isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      _isInitialized = true;
    } catch (e) {
      print('Ошибка инициализации Bluetooth: $e');
      _isInitialized = false;
    }
  }
  
  Future<bool> requestEnable() async {
    try {
      _isEnabled = await FlutterBluetoothSerial.instance.requestEnable();
      return _isEnabled;
    } catch (e) {
      print('Ошибка включения Bluetooth: $e');
      return false;
    }
  }
  
  Future<void> startDiscovery() async {
    if (!_isEnabled) return;
    
    _availableDevices.clear();
    
    try {
      _discoverySubscription = FlutterBluetoothSerial.instance
          .startDiscovery()
          .listen((BluetoothDiscoveryResult result) {
        if (!_availableDevices.any((d) => d.address == result.device.address)) {
          _availableDevices.add(result.device);
        }
      });
    } catch (e) {
      print('Ошибка поиска устройств: $e');
    }
  }
  
  Future<void> stopDiscovery() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
  }
  
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Здесь должна быть логика подключения
      // Для демонстрации просто имитируем подключение
      _connectedDevice = device;
      return true;
    } catch (e) {
      print('Ошибка подключения: $e');
      return false;
    }
  }
  
  Future<void> disconnect() async {
    _connectedDevice = null;
  }
  
  Future<bool> sendMessage(String message) async {
    if (_connectedDevice == null) return false;
    
    try {
      // Отправка сообщения через Bluetooth
      // Реальная реализация требует настройки RFCOMM канала
      print('Отправка сообщения: $message');
      return true;
    } catch (e) {
      print('Ошибка отправки: $e');
      return false;
    }
  }
  
  Stream<String> receiveMessages() async* {
    // Здесь должна быть логика получения сообщений
    // Для демонстрации пустой стрим
  }
  
  void dispose() {
    stopDiscovery();
    disconnect();
  }
}
