// lib/main.dart
import 'package:flutter/material.dart';

// Auth
import 'pages/auth/auth_gate.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';

// Main tab shell
import 'pages/shell/home_shell.dart';

void main() => runApp(const AgriVisionApp());

class AgriVisionApp extends StatelessWidget {
  const AgriVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
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
