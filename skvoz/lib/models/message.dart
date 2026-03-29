import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Message extends Equatable {
  final String id;
  final String senderId;
  final String? senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? recipientId;
  
  const Message({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.recipientId,
  });
  
  factory Message.create({
    required String senderId,
    String? senderName,
    required String content,
    MessageType type = MessageType.text,
    String? recipientId,
  }) {
    return Message(
      id: const Uuid().v4(),
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
      type: type,
      recipientId: recipientId,
    );
  }
  
  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
    String? recipientId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      recipientId: recipientId ?? this.recipientId,
    );
  }
  
  @override
  List<Object?> get props => [
        id,
        senderId,
        senderName,
        content,
        timestamp,
        isRead,
        type,
        recipientId,
      ];
}

enum MessageType {
  text,
  image,
  file,
  voice,
}
