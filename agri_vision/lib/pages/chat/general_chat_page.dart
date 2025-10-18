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
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final txt = _ctrl.text;
    ChatStore.I.postGeneral(txt);
    _ctrl.clear();
    setState(() {});
    _jumpToBottom();
  }

  void _jumpToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ChatStore.I.general;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            itemCount: msgs.length,
            itemBuilder: (context, i) {
              final m = msgs[i];
              final isMe = m.senderUser == UserSession.username;
              return _MessageTile(
                isMe: isMe,
                name: m.senderName,
                text: m.text,
                time: m.ts,
                onLongPress: isMe
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DmChatPage(peerUser: m.senderUser),
                          ),
                        ).then((_) => setState(() {}));
                      },
              );
            },
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Insert mention',
                  icon: const FaIcon(FontAwesomeIcons.at),
                  onPressed: () {
                    final others = ChatStore.I.knownUsers();
                    if (others.isEmpty) return;
                    final first = others.first;
                    _ctrl.text = '${_ctrl.text}@$first ';
                    _ctrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _ctrl.text.length),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message as ${UserSession.displayName}…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.paperPlane),
                  label: const Text('Send'),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  final bool isMe;
  final String name;
  final String text;
  final DateTime time;
  final VoidCallback? onLongPress;

  const _MessageTile({
    required this.isMe,
    required this.name,
    required this.text,
    required this.time,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? scheme.primaryContainer : scheme.surfaceVariant;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Padding(
              padding: EdgeInsets.only(left: isMe ? 48 : 4, right: isMe ? 4 : 48),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 14),
                  ),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: align,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(time),
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
    }
}
