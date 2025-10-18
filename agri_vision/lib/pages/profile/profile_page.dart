import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/activity_service.dart';
import '../../services/user_prefs.dart';
import '../auth/auth_gate.dart';
import '../results/analysis_results_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  XFile? _avatar;
  final _picker = ImagePicker();

  late int _generalSent;
  late int _dmSent;
  late int _analyses;
  DateTime? _lastActive;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadStats();

    // Auto-refresh profile counters every few seconds
    Future.doWhile(() async {
      if (!_mounted) return false;
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) _loadStats();
      return true;
    });
  }

  void _loadStats() {
    final a = ActivityService.I;
    setState(() {
      _generalSent = a.generalMessages;
      _dmSent = a.dmMessages;
      _analyses = a.photoAnalyses;
      _lastActive = a.lastActive;
    });
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
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
            for (final f in const [
              'Greenhouse',
              'Crop Farm',
              'Orchard',
              'Hydroponic',
              'Backyard Garden'
            ])
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.tractor),
                title: Text(f),
                onTap: () => Navigator.pop(context, f),
              ),
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
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => UserPrefs.region = ctrl.text.trim());
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
      appBar: AppBar(title: const Text('Profile')),
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
                          : (kIsWeb
                                  ? NetworkImage(_avatar!.path)
                                  : FileImage(File(_avatar!.path)))
                              as ImageProvider?,
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
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                        Text('@${UserSession.username}',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: -6,
                          children: [
                            _Pill(
                                icon: FontAwesomeIcons.tractor,
                                text: UserPrefs.farmType.isEmpty
                                    ? 'Farm: —'
                                    : UserPrefs.farmType),
                            _Pill(
                                icon: FontAwesomeIcons.locationDot,
                                text: UserPrefs.region.isEmpty
                                    ? 'Region: —'
                                    : UserPrefs.region),
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
                        value: '$_analyses',
                        icon: FontAwesomeIcons.magnifyingGlassChart,
                      ),
                      _Stat(
                        label: 'Last Active',
                        value: _lastActive == null
                            ? '—'
                            : _fmtTime(_lastActive!),
                        icon: FontAwesomeIcons.clock,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: ListTile(
              leading: const FaIcon(FontAwesomeIcons.flask),
              title: const Text('View Latest Analysis Results'),
              subtitle: const Text('Polished display for /results and /ai_results'),
              trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
              onTap: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AnalysisResultsPage()),
                );
                if (ok == true) {
                  setState(() {
                    ActivityService.I.onPhotoAnalyzed();
                    _analyses = ActivityService.I.photoAnalyses;
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
                  subtitle:
                      Text(UserPrefs.farmType.isEmpty ? '—' : UserPrefs.farmType),
                  trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                  onTap: _editFarmType,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.locationDot),
                  title: const Text('Region'),
                  subtitle:
                      Text(UserPrefs.region.isEmpty ? '—' : UserPrefs.region),
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

// --- helper widgets ---
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
