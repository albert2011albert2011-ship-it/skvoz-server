import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class InternetService {
  static final InternetService _instance = InternetService._internal();
  factory InternetService() => _instance;
  InternetService._internal();

  String? _serverUrl;
  String? _userId;
  WebSocket? _webSocket;
  bool _isConnected = false;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _transferProgressController = StreamController<TransferProgress>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<TransferProgress> get transferProgressStream => _transferProgressController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect(String serverUrl, String userId) async {
    _serverUrl = serverUrl;
    _userId = userId;

    try {
      final wsUrl = serverUrl.replaceFirst('http', 'ws');
      _webSocket = await WebSocket.connect('$wsUrl/ws/chat?user_id=$userId');
      _isConnected = true;
      _connectionStateController.add(true);

      _webSocket!.listen(
        (data) => _onDataReceived(data),
        onDone: () {
          _isConnected = false;
          _connectionStateController.add(false);
          _reconnect();
        },
        onError: (e) {
          print('Ошибка WebSocket: $e');
          _isConnected = false;
          _connectionStateController.add(false);
        },
      );
    } catch (e) {
      print('Ошибка подключения к серверу: $e');
      _isConnected = false;
      _connectionStateController.add(false);
      rethrow;
    }
  }

  void _onDataReceived(dynamic data) {
    try {
      final jsonData = jsonDecode(data as String) as Map<String, dynamic>;

      if (jsonData['type'] == 'message') {
        final message = ChatMessage(
          id: jsonData['id'],
          senderId: jsonData['senderId'],
          receiverId: jsonData['receiverId'],
          type: MessageType.values.firstWhere((e) => e.name == jsonData['messageType']),
          content: jsonData['content'],
          filePath: jsonData['filePath'],
          timestamp: DateTime.parse(jsonData['timestamp']),
          isIncoming: true,
          status: MessageStatus.delivered,
        );
        _messageController.add(message);
      } else if (jsonData['type'] == 'file_progress') {
        _transferProgressController.add(TransferProgress(
          transferId: jsonData['transferId'],
          fileName: jsonData['fileName'],
          totalBytes: jsonData['totalBytes'],
          transferredBytes: jsonData['transferredBytes'],
          isCompleted: jsonData['isCompleted'] ?? false,
        ));
      }
    } catch (e) {
      print('Ошибка декодирования данных Интернет: $e');
    }
  }

  Future<void> _reconnect() async {
    if (_serverUrl != null && _userId != null) {
      await Future.delayed(const Duration(seconds: 5));
      await connect(_serverUrl!, _userId!);
    }
  }

  Future<void> sendMessage(ChatMessage message) async {
    if (!_isConnected || _webSocket == null) {
      throw Exception('Нет подключения к интернету');
    }

    try {
      final jsonData = {
        'type': 'message',
        'id': message.id,
        'senderId': message.senderId,
        'receiverId': message.receiverId,
        'messageType': message.type.name,
        'content': message.content,
        'filePath': message.filePath,
        'timestamp': message.timestamp.toIso8601String(),
      };

      _webSocket!.add(jsonEncode(jsonData));
    } catch (e) {
      print('Ошибка отправки сообщения Интернет: $e');
      rethrow;
    }
  }

  Future<void> sendFile(String filePath, String receiverId, String senderId) async {
    if (!_isConnected) {
      throw Exception('Нет подключения к интернету');
    }

    try {
      final file = File(filePath);
      final fileName = filePath.split('/').last;
      final totalBytes = await file.length();
      final transferId = DateTime.now().millisecondsSinceEpoch.toString();

      // Загружаем файл на сервер через HTTP POST
      final uploadUrl = '$_serverUrl/upload';
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['sender_id'] = senderId;
      request.fields['receiver_id'] = receiverId;
      request.fields['transfer_id'] = transferId;

      var response = await request.send();

      if (response.statusCode == 200) {
        // Отправляем сообщение о файле
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: senderId,
          receiverId: receiverId,
          type: MessageType.file,
          content: fileName,
          filePath: filePath,
          timestamp: DateTime.now(),
          isIncoming: false,
          status: MessageStatus.sent,
        );

        await sendMessage(message);

        _transferProgressController.add(TransferProgress(
          transferId: transferId,
          fileName: fileName,
          totalBytes: totalBytes,
          transferredBytes: totalBytes,
          isCompleted: true,
        ));
      } else {
        throw Exception('Ошибка загрузки файла: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка отправки файла Интернет: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _webSocket?.close();
      _webSocket = null;
      _isConnected = false;
      _connectionStateController.add(false);
    } catch (e) {
      print('Ошибка отключения Интернет: $e');
    }
  }

  void dispose() {
    _messageController.close();
    _transferProgressController.close();
    _connectionStateController.close();
    disconnect();
  }
}
