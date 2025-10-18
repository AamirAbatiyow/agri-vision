// lib/pages/auth/signup_page.dart
import 'package:flutter/material.dart';

import '../../services/chat_store.dart';    // UserSession
import '../../services/user_prefs.dart';
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

  @override
  void dispose() {
    _nameCtrl
      ..dispose();
    _passCtrl
      ..dispose();
    _confirmCtrl
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300)); // mock network

    // username == display name
    final name = _nameCtrl.text.trim();
    UserSession.set(user: name, name: name);

    // Always run onboarding after signup
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
                  onSubmitted: (_) {},
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Join AgriVision',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Your username will also be your display name.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Username == Display name
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username (shown in chat)',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure1,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.length < 4) ? 'Use at least 4 characters' : null,
              ),
              const SizedBox(height: 12),

              // Confirm
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure2,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v != _passCtrl.text) ? 'Passwords do not match' : null,
              ),

              const SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(_loading ? 'Creating…' : 'Create account'),
                  onPressed: _loading ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
