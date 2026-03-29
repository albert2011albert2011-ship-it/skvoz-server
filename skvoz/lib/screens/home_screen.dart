import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/connection/connection_bloc.dart';
import '../blocs/contacts/contacts_bloc.dart';
import '../models/contact.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Инициализация подключения при запуске
    context.read<ConnectionBloc>().add(InitializeConnection());
    context.read<ContactsBloc>().add(LoadContacts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сквозь'),
        actions: [
          BlocBuilder<ConnectionBloc, ConnectionStateX>(
            builder: (context, state) {
              IconData iconData;
              String tooltip;
              
              if (state is ConnectionSuccess) {
                final connectionState = state.state;
                if (connectionState.isOnline) {
                  iconData = Icons.wifi;
                  tooltip = 'Онлайн';
                } else if (connectionState.connectionType == ConnectionType.bluetooth) {
                  iconData = Icons.bluetooth;
                  tooltip = 'Bluetooth';
                } else if (connectionState.connectionType == ConnectionType.wifiDirect) {
                  iconData = Icons.wifi_tethering;
                  tooltip = 'Wi-Fi Direct';
                } else {
                  iconData = Icons.signal_wifi_off;
                  tooltip = 'Оффлайн';
                }
              } else {
                iconData = Icons.signal_wifi_off;
                tooltip = 'Нет подключения';
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Tooltip(
                  message: tooltip,
                  child: Icon(iconData),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Контакты',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatsTab();
      case 1:
        return _buildContactsTab();
      case 2:
        return _buildSettingsTab();
      default:
        return _buildChatsTab();
    }
  }

  Widget _buildChatsTab() {
    return BlocBuilder<ContactsBloc, ContactsState>(
      builder: (context, state) {
        if (state is ContactsLoaded) {
          final contacts = state.contacts.where((c) => c.isOnline).toList();
          
          if (contacts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Нет активных чатов',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getConnectionColor(contact.connectionType),
                  child: Text(
                    contact.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(contact.name),
                subtitle: Text(_getConnectionTypeText(contact.connectionType)),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(contact: contact),
                    ),
                  );
                },
              );
            },
          );
        }
        
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildContactsTab() {
    return BlocBuilder<ContactsBloc, ContactsState>(
      builder: (context, state) {
        if (state is ContactsLoaded) {
          final contacts = state.contacts;
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: contact.isOnline
                      ? _getConnectionColor(contact.connectionType)
                      : Colors.grey,
                  child: Text(
                    contact.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(contact.name),
                subtitle: Text(
                  contact.isOnline
                      ? _getConnectionTypeText(contact.connectionType)
                      : 'Был(а) ${_formatLastSeen(contact.lastSeen)}',
                ),
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: contact.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }
        
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Подключение',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        BlocBuilder<ConnectionBloc, ConnectionStateX>(
          builder: (context, state) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.wifi),
                title: const Text('Статус подключения'),
                subtitle: Text(state is ConnectionSuccess
                    ? state.state.isOnline ? 'Онлайн' : 'Оффлайн'
                    : 'Загрузка...'),
                trailing: Switch(
                  value: state is ConnectionSuccess && state.state.isOnline,
                  onChanged: (value) {
                    // Переключение режима
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            context.read<ConnectionBloc>().add(StartBluetoothDiscovery());
          },
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Поиск устройств Bluetooth'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Поиск устройств Wi-Fi Direct
          },
          icon: const Icon(Icons.wifi_tethering),
          label: const Text('Поиск устройств Wi-Fi Direct'),
        ),
        const Divider(height: 32),
        const Text(
          'Приложение',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('О приложении'),
          subtitle: Text('Версия 1.0.0'),
        ),
        const ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('Помощь'),
        ),
      ],
    );
  }

  Color _getConnectionColor(ConnectionType? type) {
    switch (type) {
      case ConnectionType.internet:
        return Colors.blue;
      case ConnectionType.bluetooth:
        return Colors.lightBlue;
      case ConnectionType.wifiDirect:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getConnectionTypeText(ConnectionType? type) {
    switch (type) {
      case ConnectionType.internet:
        return 'Интернет';
      case ConnectionType.bluetooth:
        return 'Bluetooth';
      case ConnectionType.wifiDirect:
        return 'Wi-Fi Direct';
      default:
        return 'Оффлайн';
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'давно';
    
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }
}
