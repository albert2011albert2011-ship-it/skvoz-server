import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.light,
        primary: const Color(0xFF6C63FF),
        secondary: const Color(0xFF4CAF50),
        tertiary: const Color(0xFFFF9800),
        error: const Color(0xFFF44336),
        surface: Colors.white,
        background: const Color(0xFFF5F7FA),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1A2E),
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A2E),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF4A4A4A),
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF6B6B6B),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  static String getConnectionTypeText(ConnectionType type) {
    switch (type) {
      case ConnectionType.bluetooth:
        return 'Bluetooth';
      case ConnectionType.wifiDirect:
        return 'Wi-Fi Direct';
      case ConnectionType.internet:
        return 'Интернет';
      case ConnectionType.offline:
        return 'Оффлайн';
    }
  }

  static IconData getConnectionTypeIcon(ConnectionType type) {
    switch (type) {
      case ConnectionType.bluetooth:
        return Icons.bluetooth;
      case ConnectionType.wifiDirect:
        return Icons.wifi;
      case ConnectionType.internet:
        return Icons.cloud;
      case ConnectionType.offline:
        return Icons.cloud_off;
    }
  }

  static Color getConnectionTypeColor(ConnectionType type) {
    switch (type) {
      case ConnectionType.bluetooth:
        return const Color(0xFF2196F3);
      case ConnectionType.wifiDirect:
        return const Color(0xFF4CAF50);
      case ConnectionType.internet:
        return const Color(0xFF6C63FF);
      case ConnectionType.offline:
        return const Color(0xFF9E9E9E);
    }
  }

  static IconData getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.text:
        return Icons.message;
      case MessageType.image:
        return Icons.image;
      case MessageType.file:
        return Icons.attach_file;
      case MessageType.audio:
        return Icons.audiotrack;
      case MessageType.video:
        return Icons.videocam;
    }
  }

  static Color getMessageStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return const Color(0xFF9E9E9E);
      case MessageStatus.sending:
        return const Color(0xFFFF9800);
      case MessageStatus.sent:
        return const Color(0xFF2196F3);
      case MessageStatus.delivered:
        return const Color(0xFF4CAF50);
      case MessageStatus.read:
        return const Color(0xFF6C63FF);
      case MessageStatus.failed:
        return const Color(0xFFF44336);
    }
  }
}
