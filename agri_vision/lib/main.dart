// lib/main.dart
import 'package:flutter/material.dart';

// Auth
import 'pages/auth/auth_gate.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';

// Main tab shell
import 'pages/shell/home_shell.dart';
import 'services/user_prefs.dart';

void main() => runApp(const AgriVisionApp());

class AgriVisionApp extends StatefulWidget {
  const AgriVisionApp({super.key});

  @override
  State<AgriVisionApp> createState() => _AgriVisionAppState();
}

class _AgriVisionAppState extends State<AgriVisionApp> {
  @override
  void initState() {
    super.initState();
    // Listen for theme changes
    UserPrefs.onThemeChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: UserPrefs.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Instant transition (no animation) for best performance
      themeAnimationDuration: Duration.zero,
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGatePage(), // Pick Login / Sign Up
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignupPage(),
        '/home': (_) => const HomeShell(), // Bottom-nav shell
      },
    );
  }
}
