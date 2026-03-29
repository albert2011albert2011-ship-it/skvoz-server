import 'dart:async';
import '../models/user_profile.dart';

class AuthBloc {
  final _stateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get stateStream => _stateController.stream;
  
  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  
  bool get isAuthenticated => _currentUser != null;
  
  void login(String name, String nickname, String? email, String? phone) {
    _currentUser = UserProfile(
      id: _generateUserId(),
      name: name,
      nickname: nickname,
      email: email,
      phone: phone,
      createdAt: DateTime.now(),
    );
    _stateController.add(AuthState.authenticated(_currentUser!));
  }
  
  void logout() {
    _currentUser = null;
    _stateController.add(AuthState.unauthenticated());
  }
  
  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  void dispose() {
    _stateController.close();
  }
}

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  
  AuthState._({required this.status, this.user});
  
  factory AuthState.initial() => AuthState._(status: AuthStatus.initial);
  factory AuthState.authenticated(UserProfile user) => 
      AuthState._(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated() => 
      AuthState._(status: AuthStatus.unauthenticated);
}
