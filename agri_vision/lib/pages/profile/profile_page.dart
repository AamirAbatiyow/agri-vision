// lib/pages/profile/profile_page.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/chat_store.dart';
import '../../services/chat_api.dart';
import '../../services/user_prefs.dart';
import '../../services/activity_service.dart';
import '../auth/auth_gate.dart';
import '../results/analysis_results_page.dart'; // NEW: pretty results viewer

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  XFile? _avatar;
  final _picker = ImagePicker();

  int _generalSent = 0;
  int _dmSent = 0;
  DateTime? _lastActive;
  int _analyses = 0;

  bool _loadingCounts = false;

  @override
  void initState() {
    super.initState();
    ActivityService.I.onProfileVisited();
    _analyses = ActivityService.I.photoAnalyses; // local counter
    _refreshCounters(); // pull from server so it works even if chat tabs weren’t opened
  }

  Future<void> _refreshCounters() async {
    setState(() => _loadingCounts = true);
    try {
      final me = UserSession.username;

      // --- General messages (count mine, capture last ts) ---
      final generalRows = await ChatApi.fetchGeneral(afterIso: null, limit: 1000);
      final myGen = generalRows.where((m) => m.sender == me).toList();
      int generalCount = myGen.length;
      DateTime? last = _maxTimeList(generalRows.map((e) => DateTime.tryParse(e.ts)?.toLocal()).toList());

      // --- DM threads, then fetch each thread to count mine and latest ts ---
      final threads = await ChatApi.fetchThreads(me); // [{peer, lastTs}]
      int dmCount = 0;
      for (final t in threads) {
        final peer = (t['peer'] ?? '').toString();
        if (peer.isEmpty) continue;
        final dmRows = await ChatApi.fetchDm(a: me, b: peer, afterIso: null, limit: 1000);
        dmCount += dmRows.where((m) => m.sender == me).length;
        final dmLast = _maxTimeList(dmRows.map((e) => DateTime.tryParse(e.ts)?.toLocal()).toList());
        if (dmLast != null) last = _maxTime(last, dmLast);
      }

      setState(() {
        _generalSent = generalCount;
        _dmSent = dmCount;
        _lastActive = last;
      });
    } catch (_) {
      // keep silent; UI stays as-is
    } finally {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  DateTime? _maxTime(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }

  DateTime? _maxTimeList(List<DateTime?> arr) {
    DateTime? best;
    for (final t in arr) {
      if (t == null) continue;
      best = _maxTime(best, t);
    }
    return best;
  }

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

  String _fmtTime(DateTime t) {
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            icon: _loadingCounts
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const FaIcon(FontAwesomeIcons.rotate),
            onPressed: _loadingCounts ? null : _refreshCounters,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      child: _avatar == null ? const FaIcon(FontAwesomeIcons.leaf, size: 24) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(UserSession.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        Text('@${UserSession.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
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
                      _Stat(label: 'General Sent', value: '$_generalSent', icon: FontAwesomeIcons.earthAmericas),
                      _Stat(label: 'DMs Sent', value: '$_dmSent', icon: FontAwesomeIcons.message),
                      _Stat(label: 'Analyses', value: '$_analyses', icon: FontAwesomeIcons.magnifyingGlassChart),
                      _Stat(label: 'Last Active', value: _lastActive == null ? '—' : _fmtTime(_lastActive!), icon: FontAwesomeIcons.clock),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Pretty results viewer shortcut (no changes to camera_page.dart)
          _Card(
            child: ListTile(
              leading: const FaIcon(FontAwesomeIcons.flask),
              title: const Text('View Latest Analysis Results'),
              subtitle: const Text('Polished display for /results and /ai_results'),
              trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
              onTap: () async {
                // Open results viewer; if it fetched successfully, bump analyses count
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AnalysisResultsPage()),
                );
                if (ok == true) {
                  setState(() {
                    _analyses += 1;
                    ActivityService.I.onPhotoAnalyzed(); // keep local service in sync
                  });
                }
              },
            ),
          ),

          const SizedBox(height: 12),

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