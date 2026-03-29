import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/contact.dart';

// Events
abstract class ContactsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadContacts extends ContactsEvent {}

class AddContact extends ContactsEvent {
  final Contact contact;
  
  AddContact({required this.contact});
  
  @override
  List<Object?> get props => [contact];
}

class RemoveContact extends ContactsEvent {
  final String contactId;
  
  RemoveContact({required this.contactId});
  
  @override
  List<Object?> get props => [contactId];
}

class UpdateContactStatus extends ContactsEvent {
  final String contactId;
  final bool isOnline;
  final ConnectionType? connectionType;
  
  UpdateContactStatus({
    required this.contactId,
    required this.isOnline,
    this.connectionType,
  });
  
  @override
  List<Object?> get props => [contactId, isOnline, connectionType];
}

// States
abstract class ContactsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ContactsInitial extends ContactsState {}

class ContactsLoading extends ContactsState {}

class ContactsLoaded extends ContactsState {
  final List<Contact> contacts;
  
  ContactsLoaded({required this.contacts});
  
  @override
  List<Object?> get props => [contacts];
}

class ContactsError extends ContactsState {
  final String message;
  
  ContactsError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  ContactsBloc() : super(ContactsInitial()) {
    on<LoadContacts>(_onLoadContacts);
    on<AddContact>(_onAddContact);
    on<RemoveContact>(_onRemoveContact);
    on<UpdateContactStatus>(_onUpdateContactStatus);
  }
  
  void _onLoadContacts(
    LoadContacts event,
    Emitter<ContactsState> emit,
  ) {
    emit(ContactsLoading());
    
    // Загрузка контактов из локального хранилища
    // В реальной реализации здесь будет обращение к Hive или другому хранилищу
    final mockContacts = [
      Contact(
        id: '1',
        name: 'Алексей',
        isOnline: true,
        connectionType: ConnectionType.internet,
      ),
      Contact(
        id: '2',
        name: 'Мария',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Contact(
        id: '3',
        name: 'Дмитрий (Bluetooth)',
        isOnline: true,
        connectionType: ConnectionType.bluetooth,
      ),
    ];
    
    emit(ContactsLoaded(contacts: mockContacts));
  }
  
  void _onAddContact(
    AddContact event,
    Emitter<ContactsState> emit,
  ) {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      final updatedContacts = [...currentState.contacts, event.contact];
      emit(ContactsLoaded(contacts: updatedContacts));
    }
  }
  
  void _onRemoveContact(
    RemoveContact event,
    Emitter<ContactsState> emit,
  ) {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      final updatedContacts = currentState.contacts
          .where((c) => c.id != event.contactId)
          .toList();
      emit(ContactsLoaded(contacts: updatedContacts));
    }
  }
  
  void _onUpdateContactStatus(
    UpdateContactStatus event,
    Emitter<ContactsState> emit,
  ) {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      final updatedContacts = currentState.contacts.map((contact) {
        if (contact.id == event.contactId) {
          return contact.copyWith(
            isOnline: event.isOnline,
            connectionType: event.connectionType,
            lastSeen: event.isOnline ? null : DateTime.now(),
          );
        }
        return contact;
      }).toList();
      
      emit(ContactsLoaded(contacts: updatedContacts));
    }
  }
}
