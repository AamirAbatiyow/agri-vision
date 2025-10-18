// lib/pages/chat/chat_hub_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/activity_service.dart';
import 'general_chat_page.dart';
import 'dm_threads_page.dart';

class ChatHubPage extends StatefulWidget {
  const ChatHubPage({super.key});

  @override
  State<ChatHubPage> createState() => _ChatHubPageState();
}

class _ChatHubPageState extends State<ChatHubPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    ActivityService.I.onChatVisited(); // track visit for achievements
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(icon: FaIcon(FontAwesomeIcons.comments), text: 'General'),
            Tab(icon: FaIcon(FontAwesomeIcons.envelope), text: 'Direct'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          GeneralChatPage(),
          DmThreadsPage(),
        ],
      ),
    );
  }
}
