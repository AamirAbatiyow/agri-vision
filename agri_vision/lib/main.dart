// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // modern typography

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
      setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    // Modern color palette with enhanced light/dark variants
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32), // agricultural green
      brightness: Brightness.light,
      primary: const Color(0xFF2E7D32),
      secondary: const Color(0xFF6A994E),
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
      primary: const Color(0xFF81C784),
      secondary: const Color(0xFF9CCC65),
    );

    // Modern typography with Google Fonts (Inter for UI, Poppins for headers)
    final textTheme = GoogleFonts.interTextTheme();
    final displayTextTheme = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      title: 'AgriVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        // Apply Inter for body text and Poppins for headlines
        textTheme: textTheme.copyWith(
          displayLarge: displayTextTheme.displayLarge,
          displayMedium: displayTextTheme.displayMedium,
          displaySmall: displayTextTheme.displaySmall,
          headlineLarge: displayTextTheme.headlineLarge,
          headlineMedium: displayTextTheme.headlineMedium,
          headlineSmall: displayTextTheme.headlineSmall,
        ),
        // Enhanced button styles
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2, // subtle elevation for depth
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightScheme.surfaceContainerHighest.withOpacity(0.5),
          hintStyle: TextStyle(
            color: lightScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          labelStyle: TextStyle(color: lightScheme.onSurfaceVariant),
          // Fix for typed text color
          floatingLabelStyle: TextStyle(color: lightScheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightScheme.primary, width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2, // subtle elevation on scroll
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: lightScheme.onSurface,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        textTheme: textTheme.copyWith(
          displayLarge: displayTextTheme.displayLarge,
          displayMedium: displayTextTheme.displayMedium,
          displaySmall: displayTextTheme.displaySmall,
          headlineLarge: displayTextTheme.headlineLarge,
          headlineMedium: displayTextTheme.headlineMedium,
          headlineSmall: displayTextTheme.headlineSmall,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkScheme.surfaceContainerHighest.withOpacity(0.5),
          hintStyle: TextStyle(
            color: darkScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          labelStyle: TextStyle(color: darkScheme.onSurfaceVariant),
          // Fix for typed text color in dark mode
          floatingLabelStyle: TextStyle(color: darkScheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.primary, width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: darkScheme.onSurface,
          ),
        ),
      ),
      themeMode: UserPrefs.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
