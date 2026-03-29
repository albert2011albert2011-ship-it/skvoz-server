import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/models.dart';
import '../services/connection_manager.dart';

// Events
abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChatsEvent extends ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final ChatMessage message;
  SendMessageEvent(this.message);
  @override
  List<Object?> get props => [message];
}

class SendFileEvent extends ChatEvent {
  final String filePath;
  final String receiverId;
  final String senderId;
  SendFileEvent(this.filePath, this.receiverId, this.senderId);
  @override
  List<Object?> get props => [filePath, receiverId, senderId];
}

class ReceiveMessageEvent extends ChatEvent {
  final ChatMessage message;
  ReceiveMessageEvent(this.message);
  @override
  List<Object?> get props => [message];
}

class ConnectToDeviceEvent extends ChatEvent {
  final ConnectionType connectionType;
  final String? deviceAddress;
  final String? serverUrl;
  final String? userId;
  ConnectToDeviceEvent(this.connectionType, this.deviceAddress, {this.serverUrl, this.userId});
  @override
  List<Object?> get props => [connectionType, deviceAddress, serverUrl, userId];
}

class DisconnectEvent extends ChatEvent {}

class SelectChatEvent extends ChatEvent {
  final User participant;
  SelectChatEvent(this.participant);
  @override
  List<Object?> get props => [participant];
}

// State
class ChatState extends Equatable {
  final List<Chat> chats;
  final Chat? currentChat;
  final ConnectionType connectionType;
  final bool isConnecting;
  final bool isSending;
  final String? connectionError;
  final Map<String, TransferProgress> activeTransfers;
  final List<User> discoveredDevices;

  const ChatState({
    this.chats = const [],
    this.currentChat,
    this.connectionType = ConnectionType.offline,
    this.isConnecting = false,
    this.isSending = false,
    this.connectionError,
    this.activeTransfers = const {},
    this.discoveredDevices = const [],
  });

  ChatState copyWith({
    List<Chat>? chats,
    Chat? currentChat,
    ConnectionType? connectionType,
    bool? isConnecting,
    bool? isSending,
    String? connectionError,
    Map<String, TransferProgress>? activeTransfers,
    List<User>? discoveredDevices,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      currentChat: currentChat ?? this.currentChat,
      connectionType: connectionType ?? this.connectionType,
      isConnecting: isConnecting ?? this.isConnecting,
      isSending: isSending ?? this.isSending,
      connectionError: connectionError ?? this.connectionError,
      activeTransfers: activeTransfers ?? this.activeTransfers,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    );
  }

  @override
  List<Object?> get props => [
        chats,
        currentChat,
        connectionType,
        isConnecting,
        isSending,
        connectionError,
        activeTransfers,
        discoveredDevices,
      ];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ConnectionManager _connectionManager = ConnectionManager();

  ChatBloc() : super(const ChatState()) {
    on<LoadChatsEvent>(_onLoadChats);
    on<SendMessageEvent>(_onSendMessage);
    on<SendFileEvent>(_onSendFile);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<ConnectToDeviceEvent>(_onConnectToDevice);
    on<DisconnectEvent>(_onDisconnect);
    on<SelectChatEvent>(_onSelectChat);
    on<_ConnectionTypeChangedEvent>(_onConnectionTypeChanged);
    on<_TransferProgressEvent>(_onTransferProgress);
    on<_DiscoveredDevicesEvent>(_onDiscoveredDevices);

    _initConnectionManager();
  }

  Future<void> _initConnectionManager() async {
    await _connectionManager.initialize();

    // Подписка на изменения типа подключения
    _connectionManager.connectionTypeStream.listen((type) {
      add(_ConnectionTypeChangedEvent(type));
    });

    // Подписка на входящие сообщения
    _connectionManager.messageStream.listen((message) {
      add(ReceiveMessageEvent(message));
    });

    // Подписка на прогресс передачи файлов
    _connectionManager.transferProgressStream.listen((progress) {
      add(_TransferProgressEvent(progress));
    });
  }

  Future<void> _onLoadChats(LoadChatsEvent event, Emitter<ChatState> emit) async {
    // Загрузка чатов из локального хранилища
    emit(state.copyWith());
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<ChatState> emit) async {
    try {
      emit(state.copyWith(isSending: true));
      
      await _connectionManager.sendMessage(event.message);
      
      // Обновляем текущий чат с новым сообщением
      if (state.currentChat != null) {
        final updatedMessages = List<ChatMessage>.from(state.currentChat!.messages)
          ..add(event.message);
        
        final updatedChat = state.currentChat!.copyWith(
          messages: updatedMessages,
          lastMessage: event.message.content,
          lastMessageTime: event.message.timestamp,
        );

        emit(state.copyWith(
          currentChat: updatedChat,
          isSending: false,
        ));
      } else {
        emit(state.copyWith(isSending: false));
      }
    } catch (e) {
      emit(state.copyWith(
        isSending: false,
        connectionError: e.toString(),
      ));
    }
  }

  Future<void> _onSendFile(SendFileEvent event, Emitter<ChatState> emit) async {
    try {
      emit(state.copyWith(isSending: true));
      
      await _connectionManager.sendFile(
        event.filePath,
        event.receiverId,
        event.senderId,
      );
      
      emit(state.copyWith(isSending: false));
    } catch (e) {
      emit(state.copyWith(
        isSending: false,
        connectionError: e.toString(),
      ));
    }
  }

  Future<void> _onReceiveMessage(ReceiveMessageEvent event, Emitter<ChatState> emit) async {
    if (state.currentChat != null && 
        event.message.senderId == state.currentChat!.participant.id) {
      final updatedMessages = List<ChatMessage>.from(state.currentChat!.messages)
        ..add(event.message);
      
      final updatedChat = state.currentChat!.copyWith(
        messages: updatedMessages,
        lastMessage: event.message.content,
        lastMessageTime: event.message.timestamp,
        unreadCount: state.currentChat!.unreadCount + 1,
      );

      emit(state.copyWith(currentChat: updatedChat));
    } else if (state.currentChat == null || 
               event.message.senderId != state.currentChat!.participant.id) {
      // Сообщение от другого пользователя - можно добавить в список чатов
      // В реальной реализации здесь будет логика создания нового чата
    }
  }

  Future<void> _onConnectToDevice(ConnectToDeviceEvent event, Emitter<ChatState> emit) async {
    try {
      emit(state.copyWith(
        isConnecting: true,
        connectionError: null,
      ));

      switch (event.connectionType) {
        case ConnectionType.bluetooth:
          if (event.deviceAddress != null) {
            await _connectionManager.connectToBluetoothDevice(event.deviceAddress!);
          } else {
            await _connectionManager.startBluetoothDiscovery();
          }
          break;
        case ConnectionType.wifiDirect:
          if (event.deviceAddress != null) {
            await _connectionManager.connectToWifiDirectServer(event.deviceAddress!);
          } else {
            await _connectionManager.startWifiDirectServer();
          }
          break;
        case ConnectionType.internet:
          final serverUrl = event.serverUrl ?? 'http://localhost:3000';
          final userId = event.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
          await _connectionManager.connectToInternet(serverUrl, userId);
          break;
        case ConnectionType.offline:
          break;
      }

      emit(state.copyWith(
        isConnecting: false,
        connectionType: event.connectionType,
      ));
    } catch (e) {
      emit(state.copyWith(
        isConnecting: false,
        connectionError: e.toString(),
      ));
    }
  }

  Future<void> _onDisconnect(DisconnectEvent event, Emitter<ChatState> emit) async {
    await _connectionManager.disconnect();
    emit(state.copyWith(
      connectionType: ConnectionType.offline,
      isConnecting: false,
    ));
  }

  Future<void> _onSelectChat(SelectChatEvent event, Emitter<ChatState> emit) async {
    final chat = Chat(
      id: event.participant.id,
      participant: event.participant,
      lastMessageTime: DateTime.now(),
    );
    emit(state.copyWith(currentChat: chat));
  }

  void _onConnectionTypeChanged(_ConnectionTypeChangedEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(connectionType: event.connectionType));
  }

  void _onTransferProgress(_TransferProgressEvent event, Emitter<ChatState> emit) {
    final updatedTransfers = Map<String, TransferProgress>.from(state.activeTransfers);
    updatedTransfers[event.progress.transferId] = event.progress;
    
    if (event.progress.isCompleted || event.progress.isError) {
      updatedTransfers.remove(event.progress.transferId);
    }
    
    emit(state.copyWith(activeTransfers: updatedTransfers));
  }

  void _onDiscoveredDevices(_DiscoveredDevicesEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(discoveredDevices: event.devices));
  }

  @override
  Future<void> close() {
    _connectionManager.dispose();
    return super.close();
  }
}

// Внутренние события
class _ConnectionTypeChangedEvent extends ChatEvent {
  final ConnectionType connectionType;
  _ConnectionTypeChangedEvent(this.connectionType);
  @override
  List<Object?> get props => [connectionType];
}

class _TransferProgressEvent extends ChatEvent {
  final TransferProgress progress;
  _TransferProgressEvent(this.progress);
  @override
  List<Object?> get props => [progress];
}

class _DiscoveredDevicesEvent extends ChatEvent {
  final List<User> devices;
  _DiscoveredDevicesEvent(this.devices);
  @override
  List<Object?> get props => [devices];
}
