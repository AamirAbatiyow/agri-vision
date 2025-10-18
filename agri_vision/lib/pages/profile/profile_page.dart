// lib/pages/profile/profile_page.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/chat_store.dart';
import '../../services/user_prefs.dart';
import '../../services/activity_service.dart';
import '../auth/auth_gate.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // In-memory avatar (optional)
  XFile? _avatar;
  final _picker = ImagePicker();

  // Derived activity
  int _generalSent = 0;
  int _dmSent = 0;
  DateTime? _lastActive;

  @override
  void initState() {
    super.initState();
    ActivityService.I.onProfileVisited();
    _recomputeActivity();
  }

  void _recomputeActivity() {
    final me = UserSession.username;
    // General
    final g = ChatStore.I.general.where((m) => m.senderUser == me).toList();
    _generalSent = g.length;
    // DMs (count messages sent by me across all peers)
    int dmCount = 0;
    DateTime? last;
    for (final peer in ChatStore.I.dmPeersByRecency()) {
      final thread = ChatStore.I.dmThread(peer);
      for (final m in thread) {
        if (m.senderUser == me) dmCount++;
        last = _maxTime(last, m.ts);
      }
    }
    _dmSent = dmCount;

    // Last active: latest of any message by me (general or dms)
    for (final m in g) {
      last = _maxTime(last, m.ts);
    }
    _lastActive = last;

    setState(() {});
  }

  DateTime _maxTime(DateTime? a, DateTime b) => (a == null || b.isAfter(a)) ? b : a;

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (x != null) setState(() => _avatar = x);
  }

  Future<void> _editFarmType() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in const ['Greenhouse','Crop Farm','Orchard','Hydroponic','Backyard Garden'])
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.tractor),
                title: Text(f),
                onTap: () => Navigator.pop(context, f),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) {
      setState(() => UserPrefs.farmType = choice);
      _snack('Farm type updated');
    }
  }

  Future<void> _editRegion() async {
    final ctrl = TextEditingController(text: UserPrefs.region);
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
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => UserPrefs.region = ctrl.text.trim().isEmpty ? UserPrefs.region : ctrl.text.trim());
      _snack('Region updated');
    }
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGatePage()),
      (route) => false,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Achievements based on chat/onboarding + new activity service
  List<_Badge> _computeBadges() {
    final b = <_Badge>[];

    // Chat & onboarding
    if (_generalSent >= 1) b.add(const _Badge('First Hello', FontAwesomeIcons.solidFaceSmile));
    if (_generalSent >= 10) b.add(const _Badge('Community Regular', FontAwesomeIcons.comments));
    if (_dmSent >= 1) b.add(const _Badge('DM Starter', FontAwesomeIcons.envelope));
    if (UserPrefs.farmType.isNotEmpty) b.add(const _Badge('Farm Setup Complete', FontAwesomeIcons.tractor));
    if (UserPrefs.region.isNotEmpty && UserPrefs.region != '—') b.add(const _Badge('Region Set', FontAwesomeIcons.locationDot));

    // New (from ActivityService)
    final act = ActivityService.I;

    if (act.photoAnalyses >= 1) {
      b.add(const _Badge('First Crop Scan', FontAwesomeIcons.seedling));
    }
    if (act.photoAnalyses >= 3) {
      b.add(const _Badge('AI Analyst', FontAwesomeIcons.robot));
    }
    if (act.dashboardViews >= 5) {
      b.add(const _Badge('Weather Watcher', FontAwesomeIcons.cloudSun));
    }
    if (act.sensorTicks >= 20) {
      b.add(const _Badge('Moisture Master', FontAwesomeIcons.water));
    }
    if (act.visitedAllTabs) {
      b.add(const _Badge('AgriVision Pioneer', FontAwesomeIcons.award));
    }

    return b;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badges = _computeBadges();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            icon: const FaIcon(FontAwesomeIcons.rotate),
            onPressed: _recomputeActivity,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header / identity
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: scheme.surfaceContainerHighest,
                      backgroundImage: _avatar == null
                          ? null
                          : (kIsWeb ? NetworkImage(_avatar!.path) : FileImage(File(_avatar!.path))) as ImageProvider?,
                      child: _avatar == null
                          ? const FaIcon(FontAwesomeIcons.leaf, size: 24)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(UserSession.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        Text('@${UserSession.username}',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: -6,
                          children: [
                            _Pill(icon: FontAwesomeIcons.tractor, text: UserPrefs.farmType.isEmpty ? 'Farm: —' : UserPrefs.farmType),
                            _Pill(icon: FontAwesomeIcons.locationDot, text: UserPrefs.region.isEmpty ? 'Region: —' : UserPrefs.region),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Farm settings quick edit
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.tractor),
                  title: const Text('Farm Type'),
                  subtitle: Text(UserPrefs.farmType.isEmpty ? '—' : UserPrefs.farmType),
                  trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                  onTap: _editFarmType,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.locationDot),
                  title: const Text('Region'),
                  subtitle: Text(UserPrefs.region.isEmpty ? '—' : UserPrefs.region),
                  trailing: const FaIcon(FontAwesomeIcons.pen, size: 14),
                  onTap: _editRegion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Activity / community summary
          _Card(
            child: Column(
              children: [
                const ListTile(
                  leading: FaIcon(FontAwesomeIcons.chartLine),
                  title: Text('Your Activity'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _Stat(
                        label: 'General Sent',
                        value: '$_generalSent',
                        icon: FontAwesomeIcons.earthAmericas,
                      ),
                      _Stat(
                        label: 'DMs Sent',
                        value: '$_dmSent',
                        icon: FontAwesomeIcons.message,
                      ),
                      _Stat(
                        label: 'Analyses',
                        value: '${ActivityService.I.photoAnalyses}',
                        icon: FontAwesomeIcons.magnifyingGlassChart,
                      ),
                      _Stat(
                        label: 'Last Active',
                        value: _lastActive == null ? '—' : _fmtTime(_lastActive!),
                        icon: FontAwesomeIcons.clock,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Achievements
          if (badges.isNotEmpty)
            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Achievements', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: badges
                          .map((b) => _BadgeChip(b: b, scheme: scheme))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Logout
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

  String _fmtTime(DateTime t) {
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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

class _Badge {
  final String title;
  final IconData icon;
  const _Badge(this.title, this.icon);
}

class _BadgeChip extends StatelessWidget {
  final _Badge b;
  final ColorScheme scheme;
  const _BadgeChip({required this.b, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(b.icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(b.title, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}
