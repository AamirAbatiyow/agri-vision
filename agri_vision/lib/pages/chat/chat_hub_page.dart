// lib/pages/chat/chat_hub_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/chat_store.dart';
import 'general_chat_page.dart';
import 'dm_threads_page.dart';

class ChatHubPage extends StatelessWidget {
  const ChatHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          actions: [
            IconButton(
              tooltip: 'Reset demo data',
              icon: const FaIcon(FontAwesomeIcons.rotateLeft),
              onPressed: () {
                ChatStore.I.resetDemo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat demo reset')),
                );
                // Rebuild tabs by changing index briefly
                DefaultTabController.of(context).index = 1;
                Future.microtask(() => DefaultTabController.of(context).index = 0);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: FaIcon(FontAwesomeIcons.earthAmericas), text: 'General'),
              Tab(icon: FaIcon(FontAwesomeIcons.message), text: 'Messages'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GeneralChatPage(),
            DmThreadsPage(),
          ],
        ),
      ),
    );
  }
}
