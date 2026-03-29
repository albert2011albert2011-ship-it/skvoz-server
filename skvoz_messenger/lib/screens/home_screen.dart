import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import 'chat_screen.dart';
import 'privacy_policy_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile user;
  
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сквозь'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          final meshService = appProvider.meshService;
          
          if (meshService == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return StreamBuilder<Map<String, dynamic>>(
            stream: meshService.networkStateStream,
            initialData: {'totalUsers': 0, 'isConnected': false},
            builder: (context, snapshot) {
              final networkState = snapshot.data ?? {};
              final totalUsers = networkState['totalUsers'] as int? ?? 0;
              final isConnected = networkState['isConnected'] as bool? ?? false;
              
              return Column(
                children: [
                  // Индикатор сети
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isConnected 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isConnected ? Colors.green : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          color: isConnected ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isConnected ? 'Сеть активна' : 'Поиск устройств...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isConnected ? Colors.green : Colors.orange,
                                ),
                              ),
                              Text(
                                'Пользователей в сети: $totalUsers',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isConnected ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Список пользователей
                  Expanded(
                    child: StreamBuilder<List<UserProfile>>(
                      stream: _userListStream(meshService),
                      initialData: [],
                      builder: (context, snapshot) {
                        final users = snapshot.data ?? [];
                        
                        if (users.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет пользователей в сети',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Включите Bluetooth или WiFi для поиска',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isMe = user.id == widget.user.id;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isMe 
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.secondary,
                                  child: Text(
                                    user.nickname.isNotEmpty 
                                        ? user.nickname[0].toUpperCase()
                                        : user.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  isMe ? '${user.name} (Вы)' : user.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Theme.of(context).colorScheme.primary : null,
                                  ),
                                ),
                                subtitle: Text('@${user.nickname}'),
                                trailing: isMe 
                                    ? null
                                    : const Icon(Icons.chat_bubble_outline),
                                onTap: isMe 
                                    ? null
                                    : () => _openChat(user),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
  
  Stream<List<UserProfile>> _userListStream(meshService) async* {
    final users = <UserProfile>{};
    
    // Добавляем текущего пользователя
    yield [meshService.knownUsers.where((u) => u.id == widget.user.id).firstOrNull ?? widget.user];
    
    // Подписываемся на новых пользователей
    await for (final user in meshService.userDiscoveredStream) {
      users.add(user);
      yield [widget.user, ...users.where((u) => u.id != widget.user.id)];
    }
  }

  void _openChat(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUser: widget.user,
          chatUser: user,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы сможете войти снова в любое время.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              appProvider.logout();
              Navigator.pop(context);
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
