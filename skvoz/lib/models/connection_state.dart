import 'package:equatable/equatable.dart';

enum ConnectionType {
  internet,
  bluetooth,
  wifiDirect,
  offline,
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  searching,
}

class ConnectionState extends Equatable {
  final ConnectionType connectionType;
  final ConnectionStatus status;
  final List<String> availableDevices;
  final String? connectedDevice;
  final bool isOnline;
  
  const ConnectionState({
    this.connectionType = ConnectionType.offline,
    this.status = ConnectionStatus.disconnected,
    this.availableDevices = const [],
    this.connectedDevice,
    this.isOnline = false,
  });
  
  ConnectionState copyWith({
    ConnectionType? connectionType,
    ConnectionStatus? status,
    List<String>? availableDevices,
    String? connectedDevice,
    bool? isOnline,
  }) {
    return ConnectionState(
      connectionType: connectionType ?? this.connectionType,
      status: status ?? this.status,
      availableDevices: availableDevices ?? this.availableDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isOnline: isOnline ?? this.isOnline,
    );
  }
  
  @override
  List<Object?> get props => [
        connectionType,
        status,
        availableDevices,
        connectedDevice,
        isOnline,
      ];
}
