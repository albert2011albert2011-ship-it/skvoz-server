import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'blocs/chat/chat_bloc.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/contacts/contacts_bloc.dart';
import 'screens/home_screen.dart';
import 'services/bluetooth_service.dart';
import 'services/wifi_direct_service.dart';
import 'services/internet_service.dart';
import 'services/message_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Hive для локального хранения
  await Hive.initFlutter();
  
  // Регистрация адаптеров (будут созданы позже)
  // await Hive.openBox('messages');
  // await Hive.openBox('contacts');
  // await Hive.openBox('settings');
  
  runApp(const SkvozApp());
}

class SkvozApp extends StatelessWidget {
  const SkvozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectionBloc>(
          create: (_) => ConnectionBloc(
            bluetoothService: BluetoothService(),
            wifiDirectService: WifiDirectService(),
            internetService: InternetService(),
          ),
        ),
        BlocProvider<ContactsBloc>(
          create: (_) => ContactsBloc(),
        ),
        BlocProvider<ChatBloc>(
          create: (_) => ChatBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Сквозь',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
