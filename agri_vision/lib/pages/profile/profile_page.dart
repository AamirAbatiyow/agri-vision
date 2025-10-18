// lib/pages/profile/profile_page.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/user_prefs.dart';
import '../../services/activity_service.dart';
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

  @override
  void initState() {
    super.initState();
    ActivityService.I.onProfileVisited();
    
    // Auto-refresh stats every few seconds while on this page
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() {}); // Trigger rebuild to show latest ActivityService data
      return mounted;
    });
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
              'Backyard Garden',
            ])
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
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Edit region'),
          content: TextField(
            controller: ctrl,
            style: TextStyle(color: scheme.onSurface),
            decoration: const InputDecoration(
              labelText: 'Region',
              hintText: 'e.g., Midwest, Pacific NW',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(dialogContext, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      setState(
        () => UserPrefs.region = ctrl.text.trim().isEmpty
            ? UserPrefs.region
            : ctrl.text.trim(),
      );
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
    
    // Get live stats from ActivityService
    final stats = ActivityService.I;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
                        Text(
                          UserSession.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          '@${UserSession.username}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: -6,
                          children: [
                            _Pill(
                              icon: FontAwesomeIcons.tractor,
                              text: UserPrefs.farmType.isEmpty
                                  ? 'Farm: —'
                                  : UserPrefs.farmType,
                            ),
                            _Pill(
                              icon: FontAwesomeIcons.locationDot,
                              text: UserPrefs.region.isEmpty
                                  ? 'Region: —'
                                  : UserPrefs.region,
                            ),
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

          // Enhanced Analysis Results Card with animation
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
            child: _Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.flask,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                ),
                title: const Text(
                  'View Latest Analysis Results',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'AI-powered crop disease diagnosis',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                onTap: () {
                  // Simply navigate to results viewer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AnalysisResultsPage(),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.tractor),
                  title: const Text('Farm Type'),
                  subtitle: Text(
                    UserPrefs.farmType.isEmpty ? '—' : UserPrefs.farmType,
                  ),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: _editFarmType,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.locationDot),
                  title: const Text('Region'),
                  subtitle: Text(
                    UserPrefs.region.isEmpty ? '—' : UserPrefs.region,
                  ),
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

class _Card extends StatefulWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // animated card entrance
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          // subtle gradient for modern depth
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surface, scheme.surfaceContainerLow],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // modern pill with gradient
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withOpacity(0.5),
            scheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  State<_Stat> createState() => _StatState();
}

class _StatState extends State<_Stat> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primaryContainer.withOpacity(0.3),
                scheme.surfaceContainerHighest,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: FaIcon(widget.icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              // animated value
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  widget.value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
