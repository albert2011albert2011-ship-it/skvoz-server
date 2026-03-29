import 'dart:convert';

enum MessageType { text, file, image, location, contact }

enum MessageStatus { 
  pending,    // В очереди
  sending,    // Отправляется
  sent,       // Отправлено соседу
  delivered,  // Доставлено получателю
  read,       // Прочитано
  failed      // Ошибка
}

class MeshMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? recipientId; // null = broadcast
  final String content;
  final MessageType type;
  final String? filePath;
  final DateTime timestamp;
  final MessageStatus status;
  final List<String> routePath; // Путь прохождения сообщения [A, B, C, D]
  final int ttl; // Time to live (сколько еще узлов может пройти)
  final int hopCount; // Сколько узлов уже прошло
  
  MeshMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.recipientId,
    required this.content,
    required this.type,
    this.filePath,
    required this.timestamp,
    this.status = MessageStatus.pending,
    List<String>? routePath,
    this.ttl = 10,
    this.hopCount = 0,
  }) : routePath = routePath ?? [];

  MeshMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? content,
    MessageType? type,
    String? filePath,
    DateTime? timestamp,
    MessageStatus? status,
    List<String>? routePath,
    int? ttl,
    int? hopCount,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      routePath: routePath ?? this.routePath,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'content': content,
        'type': type.name,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'routePath': routePath,
        'ttl': ttl,
        'hopCount': hopCount,
      };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
        id: json['id'],
        senderId: json['senderId'],
        senderName: json['senderName'],
        recipientId: json['recipientId'],
        content: json['content'],
        type: MessageType.values.firstWhere((e) => e.name == json['type']),
        filePath: json['filePath'],
        timestamp: DateTime.parse(json['timestamp']),
        status: MessageStatus.values.firstWhere((e) => e.name == json['status']),
        routePath: List<String>.from(json['routePath'] ?? []),
        ttl: json['ttl'] ?? 10,
        hopCount: json['hopCount'] ?? 0,
      );
      
  bool get isExpired => hopCount >= ttl;
  
  bool shouldRelay(String myId) {
    // Не ретранслировать если я получатель
    if (recipientId == myId) return false;
    // Не ретранслировать если уже истек срок жизни
    if (isExpired) return false;
    // Не ретранслировать если я уже был в пути
    if (routePath.contains(myId)) return false;
    return true;
  }
}
