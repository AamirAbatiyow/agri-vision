// lib/pages/auth/login_page.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

import '../../services/chat_store.dart'; // UserSession
import '../../services/user_prefs.dart'; // for onboarding (if we create account here)
import '../shell/home_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  String get _apiBase {
    // Android emulator uses 10.0.2.2 to reach host machine
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://127.0.0.1:5000';
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      // 1) Try LOGIN
      final loginRes = await http.post(
        Uri.parse('$_apiBase/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (loginRes.statusCode == 200) {
        final data = jsonDecode(loginRes.body);
        if (data['success'] == true) {
          // Success: username == display name in AgriVision
          UserSession.set(user: username, name: username);
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeShell()),
            (route) => false,
          );
          return;
        } else {
          _toast(data['error'] ?? 'Login failed');
        }
      } else if (loginRes.statusCode == 401) {
        // 2) Offer to CREATE account with these credentials (nice DX for demos)
        final create = await _confirmCreate(username);
        if (create == true) {
          final signRes = await http.post(
            Uri.parse('$_apiBase/users'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'joined': _joinedLabel(),
            }),
          );

          if (signRes.statusCode == 201) {
            // Mimic signup flow: set session, run onboarding sheet once, then go home
            UserSession.set(user: username, name: username);
            final ok = await _showOnboardingSheet();
            if (ok == true && mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeShell()),
                (route) => false,
              );
            }
          } else {
            final body = _safeDecode(signRes.body);
            _toast(body['error'] ?? 'Failed to create user (${signRes.statusCode})');
          }
        }
      } else {
        _toast('Server error (${loginRes.statusCode})');
      }
    } catch (e) {
      _toast('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirmCreate(String username) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create account?'),
        content: Text('No account found for “$username”. Create one with these credentials?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[now.month - 1]} ${now.year}';
  }

  // same onboarding sheet used on signup (Farm Type + Region)
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
              left: 16, right: 16, top: 8,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Set up your farm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

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
                                'Greenhouse','Crop Farm','Orchard','Hydroponic','Backyard Garden'
                              ])
                                ListTile(title: Text(f), onTap: () => Navigator.pop(context, f)),
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

                TextField(
                  controller: region,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    hintText: 'e.g., Midwest, Pacific NW',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      UserPrefs.setOnboarding(
                        farm: farm.value,
                        reg: region.text.trim().isEmpty ? '—' : region.text.trim(),
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

  void _guest() {
    UserSession.set(user: 'guest', name: 'guest');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 8),
              Text('Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Sign in to continue to AgriVision', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 24),

              TextFormField(
                controller: _userCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login),
                  label: Text(_loading ? 'Signing in…' : 'Login'),
                  onPressed: _loading ? null : _submit,
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.userSecret, size: 16),
                  label: const Text('Continue as guest'),
                  onPressed: _loading ? null : _guest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
