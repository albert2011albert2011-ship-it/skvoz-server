import 'dart:async';
import '../models/message.dart';
import 'bluetooth_service.dart';
import 'wifi_direct_service.dart';
import 'internet_service.dart';

class MessageService {
  final BluetoothService _bluetoothService;
  final WifiDirectService _wifiDirectService;
  final InternetService _internetService;
  
  final List<Message> _localMessages = [];
  final List<Message> _pendingMessages = [];
  
  StreamController<Message> _messageController = StreamController<Message>.broadcast();
  
  MessageService({
    required BluetoothService bluetoothService,
    required WifiDirectService wifiDirectService,
    required InternetService internetService,
  })  : _bluetoothService = bluetoothService,
        _wifiDirectService = wifiDirectService,
        _internetService = internetService;
  
  Stream<Message> get messagesStream => _messageController.stream;
  List<Message> get localMessages => List.unmodifiable(_localMessages);
  List<Message> get pendingMessages => List.unmodifiable(_pendingMessages);
  
  Future<bool> sendMessage(Message message) async {
    _localMessages.add(message);
    _messageController.add(message);
    
    if (_internetService.isOnline) {
      return await _sendViaInternet(message);
    } else if (_bluetoothService.connectedDevice != null) {
      return await _sendViaBluetooth(message);
    } else if (_wifiDirectService.connectedDevice != null) {
      return await _sendViaWifiDirect(message);
    } else {
      // Нет активного подключения - сохраняем как ожидающее
      _pendingMessages.add(message);
      return false;
    }
  }
  
  Future<bool> _sendViaInternet(Message message) async {
    try {
      // Отправка через интернет (сервер, Firebase, WebSocket и т.д.)
      print('Отправка через интернет: ${message.content}');
      return true;
    } catch (e) {
      print('Ошибка отправки через интернет: $e');
      _pendingMessages.add(message);
      return false;
    }
  }
  
  Future<bool> _sendViaBluetooth(Message message) async {
    try {
      final success = await _bluetoothService.sendMessage(message.content);
      if (success) {
        return true;
      } else {
        _pendingMessages.add(message);
        return false;
      }
    } catch (e) {
      print('Ошибка отправки через Bluetooth: $e');
      _pendingMessages.add(message);
      return false;
    }
  }
  
  Future<bool> _sendViaWifiDirect(Message message) async {
    try {
      final success = await _wifiDirectService.sendMessage(message.content);
      if (success) {
        return true;
      } else {
        _pendingMessages.add(message);
        return false;
      }
    } catch (e) {
      print('Ошибка отправки через Wi-Fi Direct: $e');
      _pendingMessages.add(message);
      return false;
    }
  }
  
  void receiveMessage(Message message) {
    _localMessages.add(message);
    _messageController.add(message);
  }
  
  Future<void> retryPendingMessages() async {
    final messagesToRetry = List<Message>.from(_pendingMessages);
    _pendingMessages.clear();
    
    for (final message in messagesToRetry) {
      await sendMessage(message);
    }
  }
  
  List<Message> getMessagesForContact(String contactId) {
    return _localMessages
        .where((m) => m.recipientId == contactId || m.senderId == contactId)
        .toList();
  }
  
  void markMessageAsRead(String messageId) {
    final index = _localMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final updatedMessage = _localMessages[index].copyWith(isRead: true);
      _localMessages[index] = updatedMessage;
      _messageController.add(updatedMessage);
    }
  }
  
  void dispose() {
    _messageController.close();
  }
}
