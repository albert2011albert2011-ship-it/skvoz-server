import 'package:equatable/equatable.dart';

enum ConnectionType {
  bluetooth,
  wifiDirect,
  internet,
  offline,
}

enum MessageType {
  text,
  image,
  file,
  audio,
  video,
}

enum MessageStatus {
  pending,
  sending,
  sent,
  delivered,
  read,
  failed,
}

class User extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final ConnectionType? connectionType;

  const User({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.connectionType,
  });

  @override
  List<Object?> get props => [id, name, avatarUrl, isOnline, connectionType];

  User copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isOnline,
    ConnectionType? connectionType,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      connectionType: connectionType ?? this.connectionType,
    );
  }
}

class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final MessageType type;
  final String content;
  final String? filePath;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isIncoming;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.content,
    this.filePath,
    required this.timestamp,
    this.status = MessageStatus.pending,
    required this.isIncoming,
  });

  @override
  List<Object?> get props => [
        id,
        senderId,
        receiverId,
        type,
        content,
        filePath,
        timestamp,
        status,
        isIncoming,
      ];

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    MessageType? type,
    String? content,
    String? filePath,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isIncoming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isIncoming: isIncoming ?? this.isIncoming,
    );
  }
}

class Chat extends Equatable {
  final String id;
  final User participant;
  final List<ChatMessage> messages;
  final DateTime lastMessageTime;
  final String? lastMessage;
  final int unreadCount;

  const Chat({
    required this.id,
    required this.participant,
    this.messages = const [],
    required this.lastMessageTime,
    this.lastMessage,
    this.unreadCount = 0,
  });

  @override
  List<Object?> get props => [
        id,
        participant,
        messages,
        lastMessageTime,
        lastMessage,
        unreadCount,
      ];

  Chat copyWith({
    String? id,
    User? participant,
    List<ChatMessage>? messages,
    DateTime? lastMessageTime,
    String? lastMessage,
    int? unreadCount,
  }) {
    return Chat(
      id: id ?? this.id,
      participant: participant ?? this.participant,
      messages: messages ?? this.messages,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class TransferProgress extends Equatable {
  final String transferId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final bool isCompleted;
  final bool isError;

  const TransferProgress({
    required this.transferId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    this.isCompleted = false,
    this.isError = false,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  @override
  List<Object?> get props => [
        transferId,
        fileName,
        totalBytes,
        transferredBytes,
        isCompleted,
        isError,
      ];
}
