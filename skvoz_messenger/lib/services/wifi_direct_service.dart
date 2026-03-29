import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class WifiDirectService {
  static final WifiDirectService _instance = WifiDirectService._internal();
  factory WifiDirectService() => _instance;
  WifiDirectService._internal();

  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  bool _isServer = false;
  bool _isConnected = false;
  
  final _connectedDevices = <String>[];
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _transferProgressController = StreamController<TransferProgress>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _deviceDiscoveryController = StreamController<String>.broadcast();

  // Для приема файлов
  File? _receivingFile;
  IOSink? _fileWriter;
  int _receivedBytes = 0;
  int _expectedFileSize = 0;
  String? _currentTransferId;
  String? _currentFileName;
  final Map<String, List<int>> _fileChunks = {};

  Stream<List<String>> get connectedDevicesStream async* {
    yield _connectedDevices;
  }

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<TransferProgress> get transferProgressStream => _transferProgressController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get deviceDiscoveryStream => _deviceDiscoveryController.stream;

  bool get isConnected => _isConnected;
  bool get isServer => _isServer;

  Future<void> startServer({int port = 8080}) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isServer = true;
      _isConnected = true;
      _connectionStateController.add(true);

      print('Сервер запущен на порту $port');

      _serverSocket!.listen((socket) {
        _handleClient(socket);
      });
    } catch (e) {
      print('Ошибка запуска сервера: $e');
      rethrow;
    }
  }

  Future<void> connectToServer(String host, {int port = 8080}) async {
    try {
      _clientSocket = await Socket.connect(host, port);
      _isServer = false;
      _isConnected = true;
      _connectionStateController.add(true);

      print('Подключено к $host:$port');

      _clientSocket!.listen(
        _onDataReceived,
        onDone: () {
          _isConnected = false;
          _connectionStateController.add(false);
        },
        onError: (e) {
          print('Ошибка соединения: $e');
          _isConnected = false;
          _connectionStateController.add(false);
        },
      );
    } catch (e) {
      print('Ошибка подключения: $e');
      rethrow;
    }
  }

  void _handleClient(Socket socket) {
    _clientSocket = socket;
    _connectedDevices.add(socket.remoteAddress.address);
    _deviceDiscoveryController.add(socket.remoteAddress.address);

    socket.listen(
      _onDataReceived,
      onDone: () {
        _connectedDevices.remove(socket.remoteAddress.address);
        if (_connectedDevices.isEmpty) {
          _isConnected = false;
          _connectionStateController.add(false);
        }
      },
    );
  }

  void _onDataReceived(List<int> data) async {
    try {
      // Если мы в режиме приема файла
      if (_receivingFile != null && _fileWriter != null) {
        await _fileWriter!.add(data);
        _receivedBytes += data.length;
        
        _transferProgressController.add(TransferProgress(
          transferId: _currentTransferId ?? 'unknown',
          fileName: _currentFileName ?? 'file',
          totalBytes: _expectedFileSize,
          transferredBytes: _receivedBytes,
          isCompleted: _receivedBytes >= _expectedFileSize,
        ));

        if (_receivedBytes >= _expectedFileSize) {
          await _finishFileReception();
        }
        return;
      }

      final jsonString = utf8.decode(data);
      
      if (jsonString.startsWith('{') && jsonString.endsWith('}')) {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

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
        } else if (jsonData['type'] == 'file_info') {
          await _handleFileInfo(jsonData);
        } else if (jsonData['type'] == 'file_chunk') {
          await _handleFileChunk(jsonData);
        }
      }
    } catch (e) {
      print('Ошибка декодирования данных Wi-Fi: $e');
      // Если не удалось декодировать как JSON, возможно это сырые данные файла
      if (_receivingFile != null && _fileWriter != null) {
        await _fileWriter!.add(data);
        _receivedBytes += data.length;
        
        _transferProgressController.add(TransferProgress(
          transferId: _currentTransferId ?? 'unknown',
          fileName: _currentFileName ?? 'file',
          totalBytes: _expectedFileSize,
          transferredBytes: _receivedBytes,
        ));

        if (_receivedBytes >= _expectedFileSize) {
          await _finishFileReception();
        }
      }
    }
  }

  Future<void> sendMessage(ChatMessage message) async {
    if (!_isConnected) {
      throw Exception('Нет подключения по Wi-Fi Direct');
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

      final data = utf8.encode(jsonEncode(jsonData));
      
      if (_isServer && _serverSocket != null) {
        for (var client in _serverSocket!.toList()) {
          client.add(data);
        }
      } else if (_clientSocket != null) {
        _clientSocket!.add(data);
      }
      
      await Future.delayed(const Duration(milliseconds: 10));
    } catch (e) {
      print('Ошибка отправки сообщения Wi-Fi: $e');
      rethrow;
    }
  }

  Future<void> sendFile(String filePath, String receiverId, String senderId) async {
    if (!_isConnected) {
      throw Exception('Нет подключения по Wi-Fi Direct');
    }

    try {
      final file = File(filePath);
      final fileName = filePath.split('/').last;
      final totalBytes = await file.length();
      final transferId = DateTime.now().millisecondsSinceEpoch.toString();

      // Отправляем информацию о файле
      final fileInfo = {
        'type': 'file_info',
        'transferId': transferId,
        'fileName': fileName,
        'totalBytes': totalBytes,
        'senderId': senderId,
        'receiverId': receiverId,
      };

      _sendData(utf8.encode(jsonEncode(fileInfo)));
      await Future.delayed(const Duration(milliseconds: 50));

      // Отправляем содержимое файла частями
      final bytes = await file.readAsBytes();
      const chunkSize = 8192; // Больший размер для Wi-Fi
      int transferred = 0;

      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);

        final chunkData = {
          'type': 'file_chunk',
          'transferId': transferId,
          'chunkIndex': i ~/ chunkSize,
          'data': chunk,
        };

        _sendData(utf8.encode(jsonEncode(chunkData)));
        await Future.delayed(const Duration(milliseconds: 5));

        transferred += chunk.length;
        _transferProgressController.add(TransferProgress(
          transferId: transferId,
          fileName: fileName,
          totalBytes: totalBytes,
          transferredBytes: transferred,
        ));
      }

      // Отправляем сообщение о файле
      final message = ChatMessage(
        id: transferId,
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
    } catch (e) {
      print('Ошибка отправки файла Wi-Fi: $e');
      rethrow;
    }
  }

  void _sendData(List<int> data) {
    if (_isServer && _serverSocket != null) {
      for (var client in _serverSocket!.toList()) {
        client.add(data);
      }
    } else if (_clientSocket != null) {
      _clientSocket!.add(data);
    }
  }

  Future<void> _handleFileInfo(Map<String, dynamic> jsonData) async {
    _currentTransferId = jsonData['transferId'];
    _currentFileName = jsonData['fileName'];
    _expectedFileSize = jsonData['totalBytes'];
    _receivedBytes = 0;
    _fileChunks.clear();

    // Создаем файл для записи
    final directory = await getApplicationDocumentsDirectory();
    final savePath = '${directory.path}/received_files/$_currentFileName';
    _receivingFile = File(savePath);
    await _receivingFile!.create(recursive: true);
    _fileWriter = _receivingFile!.openWrite();

    print('Начат прием файла (Wi-Fi): $_currentFileName ($_expectedFileSize байт)');
  }

  Future<void> _handleFileChunk(Map<String, dynamic> jsonData) async {
    if (_fileWriter == null) return;

    final transferId = jsonData['transferId'];
    final chunkIndex = jsonData['chunkIndex'];
    final chunkData = jsonData['data'] as List<dynamic>;
    final chunk = chunkData.cast<int>();
    
    await _fileWriter!.add(chunk);
    _receivedBytes += chunk.length;

    _transferProgressController.add(TransferProgress(
      transferId: transferId,
      fileName: _currentFileName ?? 'file',
      totalBytes: _expectedFileSize,
      transferredBytes: _receivedBytes,
    ));

    if (_receivedBytes >= _expectedFileSize) {
      await _finishFileReception();
    }
  }

  Future<void> _finishFileReception() async {
    await _fileWriter?.close();
    _fileWriter = null;
    _receivingFile = null;

    // Отправляем сообщение о полученном файле
    final message = ChatMessage(
      id: _currentTransferId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'remote_user',
      receiverId: 'local_user',
      type: MessageType.file,
      content: _currentFileName ?? 'file',
      filePath: _receivingFile?.path,
      timestamp: DateTime.now(),
      isIncoming: true,
      status: MessageStatus.delivered,
    );
    _messageController.add(message);

    print('Файл успешно получен (Wi-Fi): $_currentFileName');
    
    _currentTransferId = null;
    _currentFileName = null;
    _receivedBytes = 0;
    _expectedFileSize = 0;
  }

  Future<String> getLocalIpAddress() async {
    final info = NetworkInfo();
    return await info.getWifiIP() ?? 'Неизвестно';
  }

  Future<void> disconnect() async {
    try {
      await _fileWriter?.close();
      _fileWriter = null;
      _receivingFile = null;
      await _serverSocket?.close();
      await _clientSocket?.close();
      _serverSocket = null;
      _clientSocket = null;
      _isConnected = false;
      _isServer = false;
      _connectedDevices.clear();
      _connectionStateController.add(false);
    } catch (e) {
      print('Ошибка отключения Wi-Fi: $e');
    }
  }

  void dispose() {
    _messageController.close();
    _transferProgressController.close();
    _connectionStateController.close();
    _deviceDiscoveryController.close();
    disconnect();
  }
}
