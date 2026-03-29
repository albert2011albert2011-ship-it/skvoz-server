import 'dart:convert';

/// Пакет для передачи в mesh-сети
/// Содержит сообщение и метаданные для маршрутизации
class MeshPacket {
  final String packetId;
  final String senderId;
  final String? targetId; // null = broadcast
  final DateTime timestamp;
  final String payloadType; // 'message', 'user_profile', 'route_request', 'route_response'
  final String payload; // JSON serialized data
  final List<String> path; // Путь прохождения пакета
  final int ttl;
  final int sequenceNumber;
  
  MeshPacket({
    required this.packetId,
    required this.senderId,
    this.targetId,
    required this.timestamp,
    required this.payloadType,
    required this.payload,
    List<String>? path,
    this.ttl = 10,
    required this.sequenceNumber,
  }) : path = path ?? [];

  Map<String, dynamic> toJson() => {
        'packetId': packetId,
        'senderId': senderId,
        'targetId': targetId,
        'timestamp': timestamp.toIso8601String(),
        'payloadType': payloadType,
        'payload': payload,
        'path': path,
        'ttl': ttl,
        'sequenceNumber': sequenceNumber,
      };

  factory MeshPacket.fromJson(Map<String, dynamic> json) => MeshPacket(
        packetId: json['packetId'],
        senderId: json['senderId'],
        targetId: json['targetId'],
        timestamp: DateTime.parse(json['timestamp']),
        payloadType: json['payloadType'],
        payload: json['payload'],
        path: List<String>.from(json['path'] ?? []),
        ttl: json['ttl'] ?? 10,
        sequenceNumber: json['sequenceNumber'],
      );

  String serialize() => jsonEncode(toJson());

  factory MeshPacket.deserialize(String data) {
    final json = jsonDecode(data);
    return MeshPacket.fromJson(json);
  }

  bool shouldForward(String myId, Set<String> processedPackets) {
    // Уже обрабатывали этот пакет
    if (processedPackets.contains(packetId)) return false;
    // TTL истек
    if (ttl <= 0) return false;
    // Я целевой получатель - не форвардить (обрабатываю локально)
    if (targetId == myId) return false;
    // Был ли я уже в пути
    if (path.contains(myId)) return false;
    return true;
  }

  MeshPacket withAddedHop(String nodeId) {
    return MeshPacket(
      packetId: packetId,
      senderId: senderId,
      targetId: targetId,
      timestamp: timestamp,
      payloadType: payloadType,
      payload: payload,
      path: [...path, nodeId],
      ttl: ttl - 1,
      sequenceNumber: sequenceNumber,
    );
  }
}

/// Типы пакетов в mesh-сети
enum MeshPacketType {
  message,         // Обычное сообщение
  userProfile,     // Профиль пользователя (для обнаружения)
  routeRequest,    // Запрос маршрута
  routeResponse,   // Ответ с маршрутом
  ack,            // Подтверждение получения
  neighborDiscovery, // Обнаружение соседей
}
