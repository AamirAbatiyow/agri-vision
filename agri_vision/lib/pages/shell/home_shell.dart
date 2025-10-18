// lib/shell/home_shell.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Tabs
import '/pages/dashboard/dashboard_page.dart';
import '/pages/camera/camera_page.dart';
import '/pages/chat/chat_hub_page.dart';
import '/pages/profile/profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with RestorationMixin {
  // Persist selected tab across app restarts (optional but nice)
  final RestorableInt _tabIndex = RestorableInt(0);

  @override
  String? get restorationId => 'home_shell';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_tabIndex, 'tab_index');
  }

  final _pages = const [
    DashboardPage(),
    CameraPage(),
    ChatHubPage(),
    ProfilePage(),
  ];

  @override
  void dispose() {
    _tabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_tabIndex.value],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex.value,
        onDestinationSelected: (i) => setState(() => _tabIndex.value = i),
        destinations: const [
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.seedling),
            label: 'Home',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.camera),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.comments),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
