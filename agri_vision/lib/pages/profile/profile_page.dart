// lib/pages/profile/profile_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/chat_store.dart';
import '../auth/auth_gate.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Local editable fields (kept in-memory for demo)
  String farmType = 'Greenhouse';
  String region = 'Midwest';

  // Mock stats
  final _rng = Random();
  int photosTaken = 0;
  int automationEvents = 0;
  int waterSavedPct = 0;

  @override
  void initState() {
    super.initState();
    _rollStats();
  }

  void _rollStats() {
    setState(() {
      photosTaken = 4 + _rng.nextInt(18);       // 4–21
      automationEvents = 3 + _rng.nextInt(12);  // 3–14
      waterSavedPct = 10 + _rng.nextInt(36);    // 10–45%
    });
  }

  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: UserSession.displayName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit display name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final name = ctrl.text.trim().isEmpty ? UserSession.username : ctrl.text.trim();
      setState(() {
        // keep same username, update display name
        UserSession.set(user: UserSession.username, name: name);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name updated.')));
      }
    }
  }

  Future<void> _pickFarmType() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _farmTypeTile('Greenhouse'),
            _farmTypeTile('Crop Farm'),
            _farmTypeTile('Orchard'),
            _farmTypeTile('Hydroponic'),
            _farmTypeTile('Backyard Garden'),
          ],
        ),
      ),
    );
    if (choice != null) setState(() => farmType = choice);
  }

  ListTile _farmTypeTile(String label) => ListTile(
        leading: const FaIcon(FontAwesomeIcons.tractor),
        title: Text(label),
        onTap: () => Navigator.pop(context, label),
      );

  Future<void> _editRegion() async {
    final ctrl = TextEditingController(text: region);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit region'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Region',
            hintText: 'e.g., Midwest, Pacific NW',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => region = ctrl.text.trim().isEmpty ? region : ctrl.text.trim());
    }
  }

  void _logout() {
    // (In-memory only) — just go back to auth gate.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGatePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh stats',
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
            onPressed: _rollStats,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account
          _Card(
            child: ListTile(
              leading: const CircleAvatar(child: FaIcon(FontAwesomeIcons.user)),
              title: Text(UserSession.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('@${UserSession.username}'),
              trailing: IconButton(
                tooltip: 'Edit display name',
                icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 18),
                onPressed: _editDisplayName,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Farm settings
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.tractor),
                  title: const Text('Farm Type'),
                  subtitle: Text(farmType),
                  trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                  onTap: _pickFarmType,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.locationDot),
                  title: const Text('Region'),
                  subtitle: Text(region),
                  trailing: const FaIcon(FontAwesomeIcons.pen, size: 14),
                  onTap: _editRegion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats
          _Card(
            child: Column(
              children: [
                const ListTile(
                  leading: FaIcon(FontAwesomeIcons.chartLine),
                  title: Text('Stats'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _Stat(scheme: scheme, label: 'Photos', value: photosTaken.toString(), icon: FontAwesomeIcons.camera),
                      _Stat(scheme: scheme, label: 'Events', value: automationEvents.toString(), icon: FontAwesomeIcons.gear),
                      _Stat(scheme: scheme, label: 'Water Saved', value: '$waterSavedPct%', icon: FontAwesomeIcons.droplet),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Danger / logout
          _Card(
            child: ListTile(
              leading: const FaIcon(FontAwesomeIcons.rightFromBracket),
              title: const Text('Log out'),
              textColor: scheme.error,
              iconColor: scheme.error,
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  final ColorScheme scheme;
  final String label;
  final String value;
  final IconData icon;

  const _Stat({
    required this.scheme,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
