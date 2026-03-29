import 'dart:async';
import 'dart:math';
import '../models/mesh_packet.dart';
import '../models/mesh_message.dart';
import '../models/user_profile.dart';

/// Менеджер маршрутизации для mesh-сети
/// Реализует алгоритм flooding с отслеживанием путей
class MeshRoutingManager {
  final String myUserId;
  
  // Обработанные пакеты (для предотвращения циклов)
  final Set<String> _processedPackets = {};
  
  // Таблица маршрутов: userId -> лучший сосед для достижения
  final Map<String, String> _routingTable = {};
  
  // Соседи: neighborId -> lastSeen
  final Map<String, DateTime> _neighbors = {};
  
  // Очередь сообщений для отправки
  final List<MeshPacket> _pendingPackets = [];
  
  // Подписчики на события
  final _packetStreamController = StreamController<MeshPacket>.broadcast();
  final _neighborStreamController = StreamController<Map<String, DateTime>>.broadcast();
  
  Stream<MeshPacket> get packetStream => _packetStreamController.stream;
  Stream<Map<String, DateTime>> get neighborStream => _neighborStreamController.stream;
  
  Map<String, DateTime> get neighbors => Map.unmodifiable(_neighbors);
  Map<String, String> get routingTable => Map.unmodifiable(_routingTable);
  
  MeshRoutingManager({required this.myUserId});
  
  /// Обработка входящего пакета
  void handleIncomingPacket(MeshPacket packet, String fromNeighbor) {
    // Обновляем информацию о соседе
    _updateNeighbor(fromNeighbor);
    
    // Проверяем, нужно ли форвардить пакет
    if (!packet.shouldForward(myUserId, _processedPackets)) {
      // Пакет не нужно форвардить, но возможно нужно обработать
      if (packet.targetId == myUserId || packet.targetId == null) {
        _processLocalPacket(packet);
      }
      return;
    }
    
    // Добавляем себя в путь и уменьшаем TTL
    final forwardedPacket = packet.withAddedHop(myUserId);
    
    // Запоминаем что обработали этот пакет
    _processedPackets.add(packet.packetId);
    
    // Очищаем старые записи (пакеты старше 5 минут)
    _cleanupProcessedPackets();
    
    // Обновляем таблицу маршрутов на основе пути
    _updateRoutingTable(packet);
    
    // Если пакет для меня - обрабатываем локально
    if (packet.targetId == myUserId || packet.targetId == null) {
      _processLocalPacket(packet);
    }
    
    // Форвардим пакет всем соседям (flooding)
    _forwardPacket(forwardedPacket);
  }
  
  /// Создание нового пакета для отправки
  MeshPacket createPacket({
    required String targetId, // null для broadcast
    required MeshPacketType type,
    required String payload,
  }) {
    return MeshPacket(
      packetId: _generatePacketId(),
      senderId: myUserId,
      targetId: targetId.isEmpty ? null : targetId,
      timestamp: DateTime.now(),
      payloadType: type.name,
      payload: payload,
      path: [myUserId],
      ttl: 10,
      sequenceNumber: _generateSequenceNumber(),
    );
  }
  
  /// Отправка пакета
  void sendPacket(MeshPacket packet) {
    _processedPackets.add(packet.packetId);
    _forwardPacket(packet);
  }
  
  /// Обновление информации о соседе
  void _updateNeighbor(String neighborId) {
    _neighbors[neighborId] = DateTime.now();
    _neighborStreamController.add(Map.unmodifiable(_neighbors));
  }
  
  /// Обновление таблицы маршрутов
  void _updateRoutingTable(MeshPacket packet) {
    // Анализируем путь пакета для оптимизации маршрутов
    final path = packet.path;
    if (path.length < 2) return;
    
    // Первый узел после отправителя - наш сосед для достижения отправителя
    final neighbor = path[1];
    final originator = path.first;
    
    // Если мы ближе к отправителю через этого соседа - обновляем маршрут
    if (!_routingTable.containsKey(originator) || 
        _routingTable[originator] != neighbor) {
      _routingTable[originator] = neighbor;
    }
    
    // Также обновляем маршруты для всех узлов в пути
    for (var i = 0; i < path.length - 1; i++) {
      final nodeId = path[i];
      if (!_routingTable.containsKey(nodeId)) {
        _routingTable[nodeId] = neighbor;
      }
    }
  }
  
  /// Обработка пакета локально
  void _processLocalPacket(MeshPacket packet) {
    // Отправляем в стрим для обработки вышестоящими слоями
    _packetStreamController.add(packet);
  }
  
  /// Форвардинг пакета всем соседям
  void _forwardPacket(MeshPacket packet) {
    // В реальной реализации здесь будет отправка через Bluetooth/WiFi Direct
    // Сейчас просто эмитим событие
    _packetStreamController.add(packet);
  }
  
  /// Генерация уникального ID пакета
  String _generatePacketId() {
    return '${myUserId}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
  
  int _generateSequenceNumber() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
  
  /// Очистка старых записей обработанных пакетов
  void _cleanupProcessedPackets() {
    // В реальной реализации нужно хранить время обработки
    // Для простоты ограничиваем размер множества
    if (_processedPackets.length > 1000) {
      final toRemove = _processedPackets.take(500).toSet();
      _processedPackets.removeAll(toRemove);
    }
  }
  
  /// Проверка, является ли пользователь соседом
  bool isNeighbor(String userId) {
    final lastSeen = _neighbors[userId];
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen).inMinutes < 5;
  }
  
  /// Получение лучшего соседа для достижения целевого пользователя
  String? getNextHop(String targetId) {
    if (targetId == myUserId) return null;
    if (_neighbors.containsKey(targetId)) return targetId; // Прямой сосед
    return _routingTable[targetId];
  }
  
  /// Удаление устаревших соседей
  void cleanupNeighbors() {
    final now = DateTime.now();
    _neighbors.removeWhere((_, lastSeen) => 
        now.difference(lastSeen).inMinutes > 5);
    _neighborStreamController.add(Map.unmodifiable(_neighbors));
  }
  
  void dispose() {
    _packetStreamController.close();
    _neighborStreamController.close();
  }
}
