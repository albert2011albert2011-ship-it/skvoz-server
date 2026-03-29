import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../bloc/auth_bloc.dart';

void main() {
  runApp(const SkvozApp());
}

class SkvozApp extends StatelessWidget {
  const SkvozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: MaterialApp(
        title: 'Сквозь',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        themeMode: ThemeMode.system,
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return StreamBuilder<AuthState>(
      stream: appProvider.authBloc!.stateStream,
      initialData: AuthState.initial(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        
        if (state == null || state.status == AuthStatus.initial) {
          return const SplashScreen();
        }
        
        if (state.status == AuthStatus.unauthenticated) {
          return const AuthScreen();
        }
        
        if (state.status == AuthStatus.authenticated) {
          return HomeScreen(user: state.user!);
        }
        
        return const SplashScreen();
      },
    );
  }
}
