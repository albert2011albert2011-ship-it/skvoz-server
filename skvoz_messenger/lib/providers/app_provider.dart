import 'package:flutter/material.dart';
import '../bloc/auth_bloc.dart';
import '../services/mesh_network_service.dart';

class AppProvider with ChangeNotifier {
  AuthBloc? _authBloc;
  MeshNetworkService? _meshService;
  
  AuthBloc? get authBloc => _authBloc;
  MeshNetworkService? get meshService => _meshService;
  
  bool get isLoggedIn => _authBloc?.isAuthenticated ?? false;
  
  void initialize() {
    _authBloc = AuthBloc();
  }
  
  Future<void> login({
    required String name,
    required String nickname,
    String? email,
    String? phone,
  }) async {
    _authBloc?.login(name, nickname, email, phone);
    
    if (_authBloc?.currentUser != null) {
      _meshService = MeshNetworkService(myProfile: _authBloc!.currentUser!);
      notifyListeners();
    }
  }
  
  void logout() {
    _meshService?.dispose();
    _meshService = null;
    _authBloc?.logout();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _meshService?.dispose();
    _authBloc?.dispose();
    super.dispose();
  }
}
