// lib/pages/auth/signup_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/user_prefs.dart';
import '../shell/home_shell.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  // Android emulator -> host machine
  static const String _backend = 'http://10.0.2.2:5000';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final res = await http
          .post(
            Uri.parse('$_backend/users'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'joined': 'Oct 2025',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 201) {
        // ✅ Create local session
        UserSession.login(username);

        // ✅ Onboarding right after successful signup
        if (!mounted) return;
        final ok = await _showOnboarding(context);
        if (!mounted) return;

        // You could persist onboarding prefs to a backend later if needed.
        // For now, navigate to the app shell.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (route) => false,
        );
        return;
      } else {
        // Try to show server error if returned
        String msg = 'Failed to create user.';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['error'] != null) {
            msg = body['error'].toString();
          }
        } catch (_) {}
        setState(() => _error = '$msg (HTTP ${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _showOnboarding(BuildContext context) async {
    // Local controllers for onboarding fields
    String farmType = UserPrefs.farmType;
    final regionCtrl = TextEditingController(text: UserPrefs.region);
    final soilCtrl = TextEditingController(text: UserPrefs.soilType);
    final favCtrl = TextEditingController(text: UserPrefs.favoriteCrop);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set up your farm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              // Farm type
              DropdownButtonFormField<String>(
                value: farmType.isEmpty ? null : farmType,
                items: const [
                  DropdownMenuItem(value: 'Greenhouse', child: Text('Greenhouse')),
                  DropdownMenuItem(value: 'Crop Farm', child: Text('Crop Farm')),
                  DropdownMenuItem(value: 'Orchard', child: Text('Orchard')),
                  DropdownMenuItem(value: 'Hydroponic', child: Text('Hydroponic')),
                  DropdownMenuItem(value: 'Backyard Garden', child: Text('Backyard Garden')),
                ],
                onChanged: (v) => farmType = v ?? '',
                decoration: const InputDecoration(
                  labelText: 'Farm Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Region
              TextField(
                controller: regionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  hintText: 'e.g., Midwest, Pacific NW',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Soil type
              TextField(
                controller: soilCtrl,
                decoration: const InputDecoration(
                  labelText: 'Soil Type',
                  hintText: 'e.g., loam, sandy loam, clay',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Favorite crop
              TextField(
                controller: favCtrl,
                decoration: const InputDecoration(
                  labelText: 'Favorite Crop',
                  hintText: 'e.g., tomatoes, corn, wheat',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Skip for now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // Save to local prefs (in-memory for now)
                        UserPrefs.farmType = farmType;
                        UserPrefs.region = regionCtrl.text.trim();
                        UserPrefs.soilType = soilCtrl.text.trim();
                        UserPrefs.favoriteCrop = favCtrl.text.trim();
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'You can edit these later in Profile.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );

    return (result ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.agriculture, size: 64),
                const SizedBox(height: 8),
                const Text(
                  'AgriVision',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),

                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.error),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        onFieldSubmitted: (_) => _signup(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(_busy ? 'Creating...' : 'Create Account'),
                          onPressed: _busy ? null : _signup,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
