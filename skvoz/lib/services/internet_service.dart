import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class InternetService {
  bool _isOnline = false;
  String? _ipAddress;
  ConnectivityResult _connectionType = ConnectivityResult.none;
  StreamSubscription? _connectivitySubscription;
  
  bool get isOnline => _isOnline;
  String? get ipAddress => _ipAddress;
  ConnectivityResult get connectionType => _connectionType;
  
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  
  Future<void> initialize() async {
    await checkConnectivity();
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _connectionType = result;
        _isOnline = result != ConnectivityResult.none;
        _updateIpAddress();
      },
    );
  }
  
  Future<void> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _connectionType = result;
      _isOnline = result != ConnectivityResult.none;
      await _updateIpAddress();
    } catch (e) {
      print('Ошибка проверки подключения: $e');
      _isOnline = false;
    }
  }
  
  Future<void> _updateIpAddress() async {
    if (_isOnline) {
      try {
        _ipAddress = await _networkInfo.getWifiIP();
      } catch (e) {
        _ipAddress = null;
      }
    } else {
      _ipAddress = null;
    }
  }
  
  bool isWiFiConnected() {
    return _connectionType == ConnectivityResult.wifi;
  }
  
  bool isMobileConnected() {
    return _connectionType == ConnectivityResult.mobile;
  }
  
  bool hasInternetAccess() {
    return _isOnline;
  }
  
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
