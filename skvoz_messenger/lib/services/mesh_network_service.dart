import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/mesh_message.dart';
import '../models/mesh_packet.dart';
import 'mesh_routing_manager.dart';

/// Сервис управления mesh-сетью
/// Объединяет маршрутизацию, обнаружение пользователей и передачу сообщений
class MeshNetworkService {
  final UserProfile _myProfile;
  final MeshRoutingManager _routingManager;
  
  // Все известные пользователи в сети
  final Map<String, UserProfile> _knownUsers = {};
  
  // Все полученные сообщения (для истории)
  final List<MeshMessage> _messageHistory = [];
  
  // Подписчики на события
  final _userDiscoveryStreamController = StreamController<UserProfile>.broadcast();
  final _messageStreamController = StreamController<MeshMessage>.broadcast();
  final _networkStateStreamController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<UserProfile> get userDiscoveredStream => _userDiscoveryStreamController.stream;
  Stream<MeshMessage> get messageReceivedStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get networkStateStream => _networkStateStreamController.stream;
  
  List<UserProfile> get knownUsers => _knownUsers.values.toList();
  List<MeshMessage> get messageHistory => List.unmodifiable(_messageHistory);
  
  MeshNetworkService({required UserProfile myProfile}) 
      : _myProfile = myProfile,
        _routingManager = MeshRoutingManager(myUserId: myProfile.id) {
    _initialize();
  }
  
  void _initialize() {
    // Подписка на пакеты от маршрутизатора
    _routingManager.packetStream.listen(_handlePacket);
    
    // Периодическая очистка соседей
    Timer.periodic(Duration(minutes: 1), (_) => _routingManager.cleanupNeighbors());
    
    // Отправляем наш профиль в сеть (broadcast)
    broadcastProfile();
    
    _emitNetworkState();
  }
  
  /// Обработка входящего пакета
  void _handlePacket(MeshPacket packet) {
    try {
      switch (packet.payloadType) {
        case 'userProfile':
          _handleUserProfilePacket(packet);
          break;
        case 'message':
          _handleMessagePacket(packet);
          break;
        case 'routeRequest':
          // Будущая реализация запроса маршрута
          break;
        case 'routeResponse':
          // Будущая реализация ответа маршрута
          break;
        case 'ack':
          // Подтверждение получения
          break;
        default:
          print('Неизвестный тип пакета: ${packet.payloadType}');
      }
    } catch (e) {
      print('Ошибка обработки пакета: $e');
    }
  }
  
  /// Обработка пакета с профилем пользователя
  void _handleUserProfilePacket(MeshPacket packet) {
    final data = jsonDecode(packet.payload);
    final profile = UserProfile.fromJson(data);
    
    // Сохраняем пользователя если еще не знали
    if (!_knownUsers.containsKey(profile.id)) {
      _knownUsers[profile.id] = profile;
      _userDiscoveryStreamController.add(profile);
      _emitNetworkState();
      
      // Отвечаем нашим профилем
      _sendProfileToUser(profile.id);
    } else {
      // Обновляем информацию если данные новее
      final existing = _knownUsers[profile.id]!;
      if (profile.createdAt.isAfter(existing.createdAt)) {
        _knownUsers[profile.id] = profile;
      }
    }
  }
  
  /// Обработка пакета с сообщением
  void _handleMessagePacket(MeshPacket packet) {
    final data = jsonDecode(packet.payload);
    final message = MeshMessage.fromJson(data);
    
    // Проверяем, не получали ли уже это сообщение
    if (_messageHistory.any((m) => m.id == message.id)) {
      return;
    }
    
    // Сохраняем сообщение
    _messageHistory.add(message);
    _messageStreamController.add(message);
    
    // Если сообщение для нас - отправляем подтверждение
    if (message.recipientId == _myProfile.id) {
      _sendAck(message.id, packet.senderId);
    }
  }
  
  /// Трансляция нашего профиля в сеть
  void broadcastProfile() {
    final packet = _routingManager.createPacket(
      targetId: '', // broadcast
      type: MeshPacketType.userProfile,
      payload: jsonEncode(_myProfile.toJson()),
    );
    _routingManager.sendPacket(packet);
  }
  
  /// Отправка профиля конкретному пользователю
  void _sendProfileToUser(String userId) {
    final packet = _routingManager.createPacket(
      targetId: userId,
      type: MeshPacketType.userProfile,
      payload: jsonEncode(_myProfile.toJson()),
    );
    _routingManager.sendPacket(packet);
  }
  
  /// Отправка сообщения пользователю
  void sendMessage({
    required String recipientId,
    required String content,
    MessageType type = MessageType.text,
    String? filePath,
  }) {
    final message = MeshMessage(
      id: Uuid().v4(),
      senderId: _myProfile.id,
      senderName: _myProfile.name,
      recipientId: recipientId,
      content: content,
      type: type,
      filePath: filePath,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      routePath: [_myProfile.id],
    );
    
    // Сохраняем локально
    _messageHistory.add(message);
    
    // Создаем пакет для отправки
    final packet = _routingManager.createPacket(
      targetId: recipientId,
      type: MeshPacketType.message,
      payload: jsonEncode(message.toJson()),
    );
    
    _routingManager.sendPacket(packet);
    
    // Обновляем статус
    final updatedMessage = message.copyWith(status: MessageStatus.sending);
    // В реальной реализации нужно обновить сообщение в истории
  }
  
  /// Отправка broadcast-сообщения (всем)
  void broadcastMessage({
    required String content,
    MessageType type = MessageType.text,
    String? filePath,
  }) {
    final message = MeshMessage(
      id: Uuid().v4(),
      senderId: _myProfile.id,
      senderName: _myProfile.name,
      recipientId: null, // broadcast
      content: content,
      type: type,
      filePath: filePath,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      routePath: [_myProfile.id],
    );
    
    _messageHistory.add(message);
    
    final packet = _routingManager.createPacket(
      targetId: '', // broadcast
      type: MeshPacketType.message,
      payload: jsonEncode(message.toJson()),
    );
    
    _routingManager.sendPacket(packet);
  }
  
  /// Отправка подтверждения
  void _sendAck(String messageId, String toUser) {
    final ackData = {'messageId': messageId, 'timestamp': DateTime.now().toIso8601String()};
    final packet = _routingManager.createPacket(
      targetId: toUser,
      type: MeshPacketType.ack,
      payload: jsonEncode(ackData),
    );
    _routingManager.sendPacket(packet);
  }
  
  /// Получение сообщений для чата с пользователем
  List<MeshMessage> getMessagesWithUser(String userId) {
    return _messageHistory
        .where((m) => 
            (m.senderId == userId && m.recipientId == _myProfile.id) ||
            (m.senderId == _myProfile.id && m.recipientId == userId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
  
  /// Проверка, доступен ли пользователь в сети
  bool isUserAvailable(String userId) {
    return _knownUsers.containsKey(userId) && 
           _routingManager.isNeighbor(userId);
  }
  
  /// Эмит состояния сети
  void _emitNetworkState() {
    _networkStateStreamController.add({
      'totalUsers': _knownUsers.length,
      'neighbors': _routingManager.neighbors.length,
      'messagesCount': _messageHistory.length,
      'isConnected': _routingManager.neighbors.isNotEmpty,
    });
  }
  
  /// Имитация получения пакета от соседнего устройства
  /// В реальной реализации вызывается Bluetooth/WiFi Direct сервисом
  void receivePacketFromNeighbor(MeshPacket packet, String neighborId) {
    _routingManager.handleIncomingPacket(packet, neighborId);
  }
  
  void dispose() {
    _routingManager.dispose();
    _userDiscoveryStreamController.close();
    _messageStreamController.close();
    _networkStateStreamController.close();
  }
}
