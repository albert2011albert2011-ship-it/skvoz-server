import 'dart:convert';

enum ConnectionType { bluetooth, wifiDirect, internet, meshRelay }

class UserProfile {
  final String id;
  final String name;
  final String nickname;
  final String? email;
  final String? phone;
  final String? publicKey; // Для будущего шифрования
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.nickname,
    this.email,
    this.phone,
    this.publicKey,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nickname': nickname,
        'email': email,
        'phone': phone,
        'publicKey': publicKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        name: json['name'],
        nickname: json['nickname'],
        email: json['email'],
        phone: json['phone'],
        publicKey: json['publicKey'],
        createdAt: DateTime.parse(json['createdAt']),
      );
      
  @override
  bool operator ==(Object other) => identical(this, other) || other is UserProfile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
