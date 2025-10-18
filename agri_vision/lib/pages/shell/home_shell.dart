// lib/shell/home_shell.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// DASHBOARD
import '../dashboard/dashboard_page.dart'; // <-- your actual file/class

// CAMERA (you replaced this with the Rekognition script, which exposes RekognitionTestPage)
import '../camera/camera_page.dart'; // provides RekognitionTestPage

// COMMUNITY
import '../chat/chat_hub_page.dart';

// AI CHAT
import '../chat/ai_chat_page.dart';

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
      builder: (_) => const DashboardPage(), // <-- use your DashboardPage
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
      label: 'AI Chat',
      icon: FontAwesomeIcons.brain,
      builder: (_) => const AiChatPage(),
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
      // smooth animated transitions between tabs
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          key: ValueKey<int>(_index),
          index: _index,
          children: _tabs
              .map((t) => _KeepAlive(child: t.builder(context)))
              .toList(),
        ),
      ),
      // enhanced navigation bar with modern styling
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: scheme.primaryContainer,
          backgroundColor: scheme.surface,
          elevation: 0,
          destinations: _tabs
              .map(
                (t) => NavigationDestination(
                  icon: FaIcon(t.icon, size: 20),
                  selectedIcon: FaIcon(
                    t.icon,
                    size: 22,
                  ), // slightly larger when selected
                  label: t.label,
                ),
              )
              .toList(),
        ),
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

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
