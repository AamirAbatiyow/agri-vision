// lib/pages/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/chat_store.dart';    // UserSession
import '../../services/user_prefs.dart';
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

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400)); // mock auth delay

    // username = display name
    final name = _userCtrl.text.trim();
    UserSession.set(user: name, name: name);

    // If onboarding is missing, ask once
    if (!UserPrefs.isOnboarded) {
      final ok = await _showOnboardingSheet();
      if (ok != true) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
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
              left: 16, right: 16, top: 8,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Set up your farm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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

                // Region
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

                // Continue
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

  void _guest() {
    // Guest also uses username=display name; no onboarding for guest by default
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

              // Username (also display name)
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

              // Password
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

              // Login button
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

              // Continue as guest
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
