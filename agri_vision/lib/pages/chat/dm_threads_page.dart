// lib/pages/chat/dm_threads_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/chat_store.dart';
import 'dm_chat_page.dart';

class DmThreadsPage extends StatefulWidget {
  const DmThreadsPage({super.key});

  @override
  State<DmThreadsPage> createState() => _DmThreadsPageState();
}

class _DmThreadsPageState extends State<DmThreadsPage> {
  @override
  Widget build(BuildContext context) {
    final peers = ChatStore.I.dmPeersByRecency();

    return Scaffold(
      body: peers.isEmpty
          ? const _EmptyDMs()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: peers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final peer = peers[i];
                final thread = ChatStore.I.dmThread(peer);
                final last = thread.isNotEmpty ? thread.last : null;

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      peer.isNotEmpty ? peer[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(peer),
                  subtitle: Text(
                    last == null ? 'No messages yet' : _preview(last.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    last == null ? '' : _formatTime(last.ts),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DmChatPage(peerUser: peer)),
                    );
                    setState(() {});
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Start new message',
        child: const FaIcon(FontAwesomeIcons.plus),
        onPressed: () => _startNewDm(context),
      ),
    );
  }

  Future<void> _startNewDm(BuildContext context) async {
    final choices = ChatStore.I.knownUsers();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other users available.')));
      return;
    }
    final peer = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PeerPicker(users: choices),
    );
    if (peer == null) return;
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DmChatPage(peerUser: peer)));
      setState(() {});
    }
  }

  String _preview(String t) {
    final s = t.replaceAll('\n', ' ').trim();
    return s.isEmpty ? '(attachment)' : s;
  }

  String _formatTime(DateTime t) {
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }
}

class _EmptyDMs extends StatelessWidget {
  const _EmptyDMs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.envelopeOpenText, size: 48),
            const SizedBox(height: 12),
            const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with someone from the community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerPicker extends StatelessWidget {
  final List<String> users;
  const _PeerPicker({required this.users});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: (context, i) {
          final u = users[i];
          return ListTile(
            leading: CircleAvatar(child: Text(u[0].toUpperCase())),
            title: Text(u),
            onTap: () => Navigator.pop(context, u),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: users.length,
      ),
    );
  }
}
