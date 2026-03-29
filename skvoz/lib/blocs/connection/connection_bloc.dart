import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/connection_state.dart';
import '../services/bluetooth_service.dart';
import '../services/wifi_direct_service.dart';
import '../services/internet_service.dart';

// Events
abstract class ConnectionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class InitializeConnection extends ConnectionEvent {}

class CheckConnectionStatus extends ConnectionEvent {}

class StartBluetoothDiscovery extends ConnectionEvent {}

class StopBluetoothDiscovery extends ConnectionEvent {}

class ConnectToDevice extends ConnectionEvent {
  final String deviceId;
  final ConnectionType connectionType;
  
  ConnectToDevice({required this.deviceId, required this.connectionType});
  
  @override
  List<Object?> get props => [deviceId, connectionType];
}

class DisconnectFromDevice extends ConnectionEvent {}

class ConnectionStatusChanged extends ConnectionEvent {
  final ConnectionState state;
  
  ConnectionStatusChanged(this.state);
  
  @override
  List<Object?> get props => [state];
}

// States
abstract class ConnectionStateX extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConnectionInitial extends ConnectionStateX {}

class ConnectionLoading extends ConnectionStateX {}

class ConnectionSuccess extends ConnectionStateX {
  final ConnectionState state;
  
  ConnectionSuccess(this.state);
  
  @override
  List<Object?> get props => [state];
}

class ConnectionError extends ConnectionStateX {
  final String message;
  
  ConnectionError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionStateX> {
  final BluetoothService bluetoothService;
  final WifiDirectService wifiDirectService;
  final InternetService internetService;
  
  ConnectionBloc({
    required this.bluetoothService,
    required this.wifiDirectService,
    required this.internetService,
  }) : super(ConnectionInitial()) {
    on<InitializeConnection>(_onInitialize);
    on<CheckConnectionStatus>(_onCheckStatus);
    on<StartBluetoothDiscovery>(_onStartBluetoothDiscovery);
    on<StopBluetoothDiscovery>(_onStopBluetoothDiscovery);
    on<ConnectToDevice>(_onConnectToDevice);
    on<DisconnectFromDevice>(_onDisconnect);
  }
  
  Future<void> _onInitialize(
    InitializeConnection event,
    Emitter<ConnectionStateX> emit,
  ) async {
    emit(ConnectionLoading());
    
    try {
      await internetService.initialize();
      await bluetoothService.initialize();
      await wifiDirectService.initialize();
      
      final state = ConnectionState(
        isOnline: internetService.isOnline,
        status: internetService.isOnline 
            ? ConnectionStatus.connected 
            : ConnectionStatus.disconnected,
        connectionType: internetService.isOnline 
            ? ConnectionType.internet 
            : ConnectionType.offline,
      );
      
      emit(ConnectionSuccess(state));
    } catch (e) {
      emit(ConnectionError('Ошибка инициализации: $e'));
    }
  }
  
  Future<void> _onCheckStatus(
    CheckConnectionStatus event,
    Emitter<ConnectionStateX> emit,
  ) async {
    await internetService.checkConnectivity();
    
    final state = ConnectionState(
      isOnline: internetService.isOnline,
      status: internetService.isOnline 
          ? ConnectionStatus.connected 
          : ConnectionStatus.disconnected,
      connectionType: internetService.isOnline 
          ? ConnectionType.internet 
          : ConnectionType.offline,
    );
    
    emit(ConnectionSuccess(state));
  }
  
  Future<void> _onStartBluetoothDiscovery(
    StartBluetoothDiscovery event,
    Emitter<ConnectionStateX> emit,
  ) async {
    if (state is ConnectionSuccess) {
      final currentState = (state as ConnectionSuccess).state;
      emit(ConnectionSuccess(currentState.copyWith(
        status: ConnectionStatus.searching,
      )));
      
      await bluetoothService.startDiscovery();
      
      emit(ConnectionSuccess(currentState.copyWith(
        status: ConnectionStatus.connected,
        availableDevices: bluetoothService.availableDevices.map((d) => d.name).toList(),
      )));
    }
  }
  
  Future<void> _onStopBluetoothDiscovery(
    StopBluetoothDiscovery event,
    Emitter<ConnectionStateX> emit,
  ) async {
    await bluetoothService.stopDiscovery();
    
    if (state is ConnectionSuccess) {
      final currentState = (state as ConnectionSuccess).state;
      emit(ConnectionSuccess(currentState.copyWith(
        status: ConnectionStatus.disconnected,
      )));
    }
  }
  
  Future<void> _onConnectToDevice(
    ConnectToDevice event,
    Emitter<ConnectionStateX> emit,
  ) async {
    if (state is ConnectionSuccess) {
      final currentState = (state as ConnectionSuccess).state;
      emit(ConnectionSuccess(currentState.copyWith(
        status: ConnectionStatus.connecting,
      )));
      
      bool success = false;
      
      switch (event.connectionType) {
        case ConnectionType.bluetooth:
          // Найти устройство по имени и подключиться
          final device = bluetoothService.availableDevices
              .firstWhere((d) => d.name == event.deviceId);
          success = await bluetoothService.connectToDevice(device);
          break;
        case ConnectionType.wifiDirect:
          success = await wifiDirectService.connectToDevice(event.deviceId);
          break;
        default:
          break;
      }
      
      if (success) {
        emit(ConnectionSuccess(currentState.copyWith(
          status: ConnectionStatus.connected,
          connectedDevice: event.deviceId,
          connectionType: event.connectionType,
        )));
      } else {
        emit(ConnectionError('Не удалось подключиться к устройству'));
      }
    }
  }
  
  Future<void> _onDisconnect(
    DisconnectFromDevice event,
    Emitter<ConnectionStateX> emit,
  ) async {
    await bluetoothService.disconnect();
    await wifiDirectService.disconnect();
    
    if (state is ConnectionSuccess) {
      final currentState = (state as ConnectionSuccess).state;
      emit(ConnectionSuccess(currentState.copyWith(
        status: ConnectionStatus.disconnected,
        connectedDevice: null,
        connectionType: internetService.isOnline 
            ? ConnectionType.internet 
            : ConnectionType.offline,
      )));
    }
  }
}
