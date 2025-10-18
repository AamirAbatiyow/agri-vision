// lib/pages/auth/signup_page.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/chat_store.dart'; // UserSession
import '../../services/user_prefs.dart'; // onboarding storage (farmType/region)
import '../../services/activity_service.dart';
import '../shell/home_shell.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true, _obscure2 = true, _loading = false;

  String get _apiBase {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.102.96.77:8000';
    return 'http://127.0.0.1:5000';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final username = _nameCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      final url = Uri.parse('$_apiBase/users'); // Flask "create user"
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'joined': _joinedLabel(), // optional; matches your example
        }),
      );

      if (res.statusCode == 201) {
        // Set local session (username == display name)
        UserSession.set(user: username, name: username);

        // Set last active time on signup
        ActivityService.I.lastActive = DateTime.now();

        // Collect onboarding (Farm Type + Region) locally
        final ok = await _showOnboardingSheet();
        if (!mounted) return;

        if (ok == true) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeShell()),
            (route) => false,
          );
        } else {
          setState(() => _loading = false);
        }
      } else {
        final body = _safeDecode(res.body);
        _toast(body['error'] ?? 'Failed to create user (${res.statusCode})');
      }
    } catch (e) {
      _toast('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _safeDecode(String s) {
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String _joinedLabel() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Future<bool?> _showOnboardingSheet() {
    final farm = ValueNotifier<String>('Greenhouse');
    final region = TextEditingController();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set up your farm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // Farm type picker
                ValueListenableBuilder<String>(
                  valueListenable: farm,
                  builder: (_, v, __) => ListTile(
                    leading: const Icon(Icons.agriculture),
                    title: const Text('Farm Type'),
                    subtitle: Text(v),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final pick = await showModalBottomSheet<String>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final f in const [
                                'Greenhouse',
                                'Crop Farm',
                                'Orchard',
                                'Hydroponic',
                                'Backyard Garden',
                              ])
                                ListTile(
                                  title: Text(f),
                                  onTap: () => Navigator.pop(context, f),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                      if (pick != null) farm.value = pick;
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Region field
                Builder(
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return TextField(
                      controller: region,
                      style: TextStyle(color: scheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Region',
                        hintText: 'e.g., Midwest, Pacific NW',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Continue
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      UserPrefs.setOnboarding(
                        farm: farm.value,
                        reg: region.text.trim().isEmpty
                            ? '—'
                            : region.text.trim(),
                      );
                      Navigator.pop(context, true);
                    },
                    child: const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      // gradient background for visual depth
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, scheme.surfaceContainerLow],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // animated header entrance
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join AgriVision',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: scheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your username will also be your display name.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // animated form fields
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // Username field with modern styling
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: scheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Username (shown in chat)',
                          hintText: 'Choose a username',
                          prefixIcon: Icon(Icons.person, color: scheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter a username'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure1,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: scheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'At least 4 characters',
                          prefixIcon: Icon(Icons.lock, color: scheme.primary),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure1 = !_obscure1),
                            icon: Icon(
                              _obscure1
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 4)
                            ? 'Use at least 4 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Confirm password
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscure2,
                        onFieldSubmitted: (_) => _submit(),
                        style: TextStyle(color: scheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          hintText: 'Re-enter your password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: scheme.primary,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure2 = !_obscure2),
                            icon: Icon(
                              _obscure2
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) => (v != _passCtrl.text)
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // animated Create button
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.9 + (0.1 * value),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      icon: _loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scheme.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _loading ? 'Creating…' : 'Create account',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: _loading ? null : _submit,
                    ),
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
