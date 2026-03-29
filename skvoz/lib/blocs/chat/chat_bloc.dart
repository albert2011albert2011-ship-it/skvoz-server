import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/message.dart';
import '../services/message_service.dart';

// Events
abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {
  final String contactId;
  
  LoadMessages({required this.contactId});
  
  @override
  List<Object?> get props => [contactId];
}

class SendMessage extends ChatEvent {
  final Message message;
  
  SendMessage({required this.message});
  
  @override
  List<Object?> get props => [message];
}

class MarkMessageAsRead extends ChatEvent {
  final String messageId;
  
  MarkMessageAsRead({required this.messageId});
  
  @override
  List<Object?> get props => [messageId];
}

class RetryPendingMessages extends ChatEvent {}

// States
abstract class ChatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<Message> messages;
  final List<Message> pendingMessages;
  
  ChatLoaded({
    required this.messages,
    required this.pendingMessages,
  });
  
  @override
  List<Object?> get props => [messages, pendingMessages];
}

class ChatError extends ChatState {
  final String message;
  
  ChatError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<MarkMessageAsRead>(_onMarkMessageAsRead);
    on<RetryPendingMessages>(_onRetryPendingMessages);
  }
  
  void _onLoadMessages(
    LoadMessages event,
    Emitter<ChatState> emit,
  ) {
    emit(ChatLoading());
    
    // Загрузка сообщений из сервиса
    // В реальной реализации здесь будет обращение к MessageService
    emit(ChatLoaded(messages: [], pendingMessages: []));
  }
  
  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      
      // Добавляем сообщение в список
      final updatedMessages = [...currentState.messages, event.message];
      
      emit(ChatLoaded(
        messages: updatedMessages,
        pendingMessages: currentState.pendingMessages,
      ));
      
      // Отправка через сервис
      // В реальной реализации здесь будет вызов messageService.sendMessage(event.message)
    }
  }
  
  void _onMarkMessageAsRead(
    MarkMessageAsRead event,
    Emitter<ChatState> emit,
  ) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      
      final updatedMessages = currentState.messages.map((msg) {
        if (msg.id == event.messageId) {
          return msg.copyWith(isRead: true);
        }
        return msg;
      }).toList();
      
      emit(ChatLoaded(
        messages: updatedMessages,
        pendingMessages: currentState.pendingMessages,
      ));
    }
  }
  
  void _onRetryPendingMessages(
    RetryPendingMessages event,
    Emitter<ChatState> emit,
  ) {
    // Повторная отправка ожидающих сообщений
    // В реальной реализации здесь будет вызов messageService.retryPendingMessages()
  }
}
