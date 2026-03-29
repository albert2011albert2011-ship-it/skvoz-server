import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_profile.dart';
import '../models/mesh_message.dart';
import '../providers/app_provider.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final UserProfile currentUser;
  final UserProfile chatUser;
  
  const ChatScreen({
    super.key, 
    required this.currentUser,
    required this.chatUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<MeshMessage> _messages = [];
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _loadMessages() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final meshService = appProvider.meshService;
    
    if (meshService != null) {
      setState(() {
        _messages = meshService.getMessagesWithUser(widget.chatUser.id);
      });
      
      // Подписка на новые сообщения
      meshService.messageReceivedStream.listen((message) {
        if (message.senderId == widget.chatUser.id || 
            message.recipientId == widget.chatUser.id) {
          if (mounted) {
            setState(() {
              _messages = meshService.getMessagesWithUser(widget.chatUser.id);
            });
            _scrollToBottom();
          }
        }
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final meshService = appProvider.meshService;
    
    if (meshService != null) {
      meshService.sendMessage(
        recipientId: widget.chatUser.id,
        content: _messageController.text.trim(),
        type: MessageType.text,
      );
      
      _messageController.clear();
      setState(() {
        _messages = meshService.getMessagesWithUser(widget.chatUser.id);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    _typingTimer?.cancel();
    
    if (!_isTyping && text.isNotEmpty) {
      setState(() => _isTyping = true);
      // Здесь можно отправить индикатор набора текста
    }
    
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping && mounted) {
        setState(() => _isTyping = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(
                widget.chatUser.nickname.isNotEmpty 
                    ? widget.chatUser.nickname[0].toUpperCase()
                    : widget.chatUser.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatUser.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@${widget.chatUser.nickname}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Звонки будут доступны в будущем')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Индикатор набора текста
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${widget.chatUser.name} печатает...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // Список сообщений
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == widget.currentUser.id;
                      
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          // Поле ввода
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет сообщений',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Отправьте первое сообщение!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MeshMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(
                message.senderName.isNotEmpty 
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.routePath.length > 2)
                    Text(
                      'Через: ${message.routePath.skip(1).take(message.routePath.length - 2).join(" → ")}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe 
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[700],
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe 
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[600],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case MessageStatus.pending:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case MessageStatus.sending:
        icon = Icons.send;
        color = Colors.blue;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.blue;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.green;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }
    
    return Icon(icon, size: 14, color: color);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _showAttachOptions,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: _onTextChanged,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Сообщение...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Фото'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Выбор фото будет доступен скоро')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Файл'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Выбор файла будет доступен скоро')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Местоположение'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Геолокация будет доступна скоро')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Профиль'),
              onTap: () {
                Navigator.pop(context);
                _showUserProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off),
              title: const Text('Отключить уведомления'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Уведомления отключены')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Заблокировать'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пользователь заблокирован')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.chatUser.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Никнейм: @${widget.chatUser.nickname}'),
            if (widget.chatUser.email != null)
              Text('Email: ${widget.chatUser.email}'),
            if (widget.chatUser.phone != null)
              Text('Телефон: ${widget.chatUser.phone}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
