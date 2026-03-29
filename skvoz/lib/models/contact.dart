import 'package:equatable/equatable.dart';

class Contact extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? deviceId;
  final bool isOnline;
  final ConnectionType? connectionType;
  final DateTime? lastSeen;
  
  const Contact({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.deviceId,
    this.isOnline = false,
    this.connectionType,
    this.lastSeen,
  });
  
  Contact copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? deviceId,
    bool? isOnline,
    ConnectionType? connectionType,
    DateTime? lastSeen,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      deviceId: deviceId ?? this.deviceId,
      isOnline: isOnline ?? this.isOnline,
      connectionType: connectionType ?? this.connectionType,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
  
  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        deviceId,
        isOnline,
        connectionType,
        lastSeen,
      ];
}

enum ConnectionType {
  internet,
  bluetooth,
  wifiDirect,
  local,
}
