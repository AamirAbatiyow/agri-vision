// lib/shell/home_shell.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// DASHBOARD
import '../dashboard/dashboard_page.dart';   // <-- your actual file/class

// CAMERA (you replaced this with the Rekognition script, which exposes RekognitionTestPage)
import '../camera/camera_page.dart';    // provides RekognitionTestPage

// COMMUNITY
import '../chat/chat_hub_page.dart';

// PROFILE
import '../profile/profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<_TabInfo> _tabs = [
    _TabInfo(
      label: 'Dashboard',
      icon: FontAwesomeIcons.gaugeHigh,
      builder: (_) => const DashboardPage(),     // <-- use your DashboardPage
    ),
    _TabInfo(
      label: 'Camera',
      icon: FontAwesomeIcons.camera,
      builder: (_) => const RekognitionTestPage(), // <-- from camera_page.dart
    ),
    _TabInfo(
      label: 'Community',
      icon: FontAwesomeIcons.comments,
      builder: (_) => const ChatHubPage(),
    ),
    _TabInfo(
      label: 'Profile',
      icon: FontAwesomeIcons.user,
      builder: (_) => const ProfilePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _tabs.map((t) => _KeepAlive(child: t.builder(context))).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: scheme.primaryContainer,
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: FaIcon(t.icon, size: 18),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  _TabInfo({required this.label, required this.icon, required this.builder});
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child, super.key});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
