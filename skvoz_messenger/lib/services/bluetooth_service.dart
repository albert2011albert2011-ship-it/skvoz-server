import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  BluetoothConnection? _connection;
  bool _isDiscovering = false;
  bool _isConnected = false;
  
  final _discoveredDevices = <BluetoothDiscoveryResult>[];
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _transferProgressController = StreamController<TransferProgress>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  // Для приема файлов
  File? _receivingFile;
  IOSink? _fileWriter;
  int _receivedBytes = 0;
  int _expectedFileSize = 0;
  String? _currentTransferId;
  String? _currentFileName;

  Stream<List<BluetoothDiscoveryResult>> get discoveredDevicesStream async* {
    yield _discoveredDevices;
  }

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<TransferProgress> get transferProgressStream => _transferProgressController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _isConnected;
  bool get isDiscovering => _isDiscovering;

  List<BluetoothDiscoveryResult> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  Future<void> startDiscovery({Duration duration = const Duration(seconds: 10)}) async {
    if (_isDiscovering) return;

    _discoveredDevices.clear();
    _isDiscovering = true;
    _connectionStateController.add(false);

    try {
      // Проверяем включен ли Bluetooth
      if (!await FlutterBluetoothSerial.instance.isEnabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      _discoverySubscription = FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        if (!_discoveredDevices.any((d) => d.address == result.address)) {
          _discoveredDevices.add(result);
        }
      });

      await Future.delayed(duration);
      await stopDiscovery();
    } catch (e) {
      print('Ошибка обнаружения: $e');
      _isDiscovering = false;
    }
  }

  Future<void> stopDiscovery() async {
    await _discoverySubscription?.cancel();
    _isDiscovering = false;
  }

  Future<bool> connect(String address) async {
    try {
      _connection = await BluetoothConnection.toAddress(address);
      _isConnected = true;
      _connectionStateController.add(true);

      _connection!.input!.listen(_onDataReceived).onDone(() {
        _isConnected = false;
        _connectionStateController.add(false);
      });

      return true;
    } catch (e) {
      print('Ошибка подключения: $e');
      _isConnected = false;
      _connectionStateController.add(false);
      return false;
    }
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

      // Пытаемся декодировать как JSON (для сообщений и метаданных)
      final jsonString = utf8.decode(data);
      
      // Проверяем, не является ли это сырыми данными файла
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
      print('Ошибка декодирования данных Bluetooth: $e');
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

  Future<void> _handleFileInfo(Map<String, dynamic> jsonData) async {
    _currentTransferId = jsonData['transferId'];
    _currentFileName = jsonData['fileName'];
    _expectedFileSize = jsonData['totalBytes'];
    _receivedBytes = 0;

    // Создаем файл для записи
    final directory = await getApplicationDocumentsDirectory();
    final savePath = '${directory.path}/received_files/$_currentFileName';
    _receivingFile = File(savePath);
    await _receivingFile!.create(recursive: true);
    _fileWriter = _receivingFile!.openWrite();

    print('Начат прием файла: $_currentFileName ($_expectedFileSize байт)');
  }

  Future<void> _handleFileChunk(Map<String, dynamic> jsonData) async {
    if (_fileWriter == null) return;

    final chunkData = jsonData['data'] as List<dynamic>;
    final chunk = chunkData.cast<int>();
    
    await _fileWriter!.add(chunk);
    _receivedBytes += chunk.length;

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

    print('Файл успешно получен: $_currentFileName');
    
    _currentTransferId = null;
    _currentFileName = null;
    _receivedBytes = 0;
    _expectedFileSize = 0;
  }

  Future<void> sendMessage(ChatMessage message) async {
    if (!_isConnected || _connection == null) {
      throw Exception('Нет подключения по Bluetooth');
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
      _connection!.output.add(data);
      await _connection!.output.allSent;
    } catch (e) {
      print('Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  Future<void> sendFile(String filePath, String receiverId, String senderId) async {
    if (!_isConnected || _connection == null) {
      throw Exception('Нет подключения по Bluetooth');
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

      _connection!.output.add(utf8.encode(jsonEncode(fileInfo)));
      await _connection!.output.allSent;
      
      // Небольшая задержка перед отправкой данных
      await Future.delayed(const Duration(milliseconds: 100));

      // Отправляем содержимое файла частями
      final bytes = await file.readAsBytes();
      const chunkSize = 512; // Меньший размер для стабильности Bluetooth
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

        _connection!.output.add(utf8.encode(jsonEncode(chunkData)));
        await _connection!.output.allSent;
        
        transferred += chunk.length;
        _transferProgressController.add(TransferProgress(
          transferId: transferId,
          fileName: fileName,
          totalBytes: totalBytes,
          transferredBytes: transferred,
        ));

        // Задержка для стабильности передачи
        await Future.delayed(const Duration(milliseconds: 20));
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
      print('Ошибка отправки файла: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _fileWriter?.close();
      _fileWriter = null;
      _receivingFile = null;
      await _connection?.finish();
      _connection = null;
      _isConnected = false;
      _connectionStateController.add(false);
    } catch (e) {
      print('Ошибка отключения: $e');
    }
  }

  void dispose() {
    _discoverySubscription?.cancel();
    _connectionSubscription?.cancel();
    _messageController.close();
    _transferProgressController.close();
    _connectionStateController.close();
    disconnect();
  }
}
