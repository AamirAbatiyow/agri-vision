// lib/pages/chat/general_chat_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/chat_store.dart';
import 'dm_chat_page.dart';

class GeneralChatPage extends StatefulWidget {
  const GeneralChatPage({super.key});

  @override
  State<GeneralChatPage> createState() => _GeneralChatPageState();
}

class _GeneralChatPageState extends State<GeneralChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // begin polling Mongo general channel
    ChatStore.I.startGeneralPolling();
    // listen for updates to auto-scroll
    ChatStore.I.addListener(_scrollToEndSafe);
  }

  @override
  void dispose() {
    ChatStore.I.removeListener(_scrollToEndSafe);
    // keep polling running while user is on other tabs? Up to you.
    // If you want to stop when leaving this tab, uncomment next line:
    // ChatStore.I.stopGeneralPolling();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await ChatStore.I.postGeneral(text); // optimistic append inside store
    _input.clear();
    _scrollToEndSafe();
  }

  void _scrollToEndSafe() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _maybeOpenDm(String sender) async {
    final me = UserSession.username;
    if (sender == me) return; // no DM with self
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start Direct Message'),
        content: Text('Message @$sender privately?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DmChatPage(peerUsername: sender)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = UserSession.username;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header / tip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.earthAmericas, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'General Chat — long-press a message to DM its sender.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: AnimatedBuilder(
            animation: ChatStore.I,
            builder: (_, __) {
              final items = ChatStore.I.general;
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final m = items[i];
                  final mine = m.mine || m.senderUser == me;
                  final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                  final bubbleColor = mine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
                  final textColor = mine ? scheme.onPrimaryContainer : scheme.onSurface;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: align,
                      children: [
                        Row(
                          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!mine)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: scheme.surfaceContainerHigh,
                                  child: const FaIcon(FontAwesomeIcons.user, size: 12),
                                ),
                              ),
                            Flexible(
                              child: GestureDetector(
                                onLongPress: () => _maybeOpenDm(m.senderUser),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: bubbleColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(14),
                                      topRight: const Radius.circular(14),
                                      bottomLeft: Radius.circular(mine ? 14 : 4),
                                      bottomRight: Radius.circular(mine ? 4 : 14),
                                    ),
                                    border: Border.all(color: scheme.outlineVariant),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!mine)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '@${m.senderUser}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      Text(m.text, style: TextStyle(color: textColor)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (mine)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: scheme.surfaceContainerHigh,
                                  child: const FaIcon(FontAwesomeIcons.userAstronaut, size: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtTime(m.ts),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Composer
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message the community…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _send,
                  icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime t) {
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    final today = DateTime.now();
    final isToday = t.year == today.year && t.month == today.month && t.day == today.day;
    return isToday ? '$hh:$mm $ampm' : '${t.month}/${t.day}/${t.year.toString().substring(2)}';
  }
}
