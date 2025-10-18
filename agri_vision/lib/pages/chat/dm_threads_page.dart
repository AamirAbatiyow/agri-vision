// lib/pages/chat/dm_threads_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/chat_store.dart';
import '../../services/chat_api.dart';
import 'dm_chat_page.dart';

class DmThreadsPage extends StatefulWidget {
  const DmThreadsPage({super.key});

  @override
  State<DmThreadsPage> createState() => _DmThreadsPageState();
}

class _DmThreadsPageState extends State<DmThreadsPage> {
  final _searchCtrl = TextEditingController();
  final _newDmCtrl = TextEditingController();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  List<_Thread> _threads = [];
  bool _loading = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _autoTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _searchCtrl.dispose();
    _newDmCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final me = UserSession.username;
      final rows = await ChatApi.fetchThreads(me);
      final remote = rows
          .map(
            (r) => _Thread(
              peer: (r['peer'] ?? '').toString(),
              lastTs: DateTime.tryParse(
                (r['lastTs'] ?? '').toString(),
              )?.toLocal(),
            ),
          )
          .where((t) => t.peer.isNotEmpty)
          .toList();

      final localPeers = ChatStore.I.dmPeersByRecency();
      for (final p in localPeers) {
        if (p == me) continue;
        if (!remote.any((t) => t.peer == p)) {
          final list = ChatStore.I.dmThread(p);
          final last = list.isNotEmpty ? list.last.ts : null;
          remote.add(_Thread(peer: p, lastTs: last));
        }
      }

      remote.sort((a, b) {
        final at = a.lastTs ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.lastTs ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

      if (mounted) setState(() => _threads = remote);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDm(String peer) {
    if (peer.isEmpty || peer == UserSession.username) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DmChatPage(peerUsername: peer)));
  }

  Future<void> _createDmDialog() async {
    _newDmCtrl.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start new DM'),
        content: TextField(
          controller: _newDmCtrl,
          decoration: const InputDecoration(
            labelText: 'Peer username',
            hintText: 'e.g., farmer_jane',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final peer = _newDmCtrl.text.trim();
      if (peer.isEmpty || peer == UserSession.username) return;
      ChatStore.I.dmThread(peer);
      if (mounted) setState(() {});
      _openDm(peer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _threads
        : _threads.where((t) => t.peer.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search users…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Start new DM',
                child: FilledButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14),
                  label: const Text('New'),
                  onPressed: _createDmDialog,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: RefreshIndicator(
            key: _refreshKey,
            onRefresh: _load,
            child: _loading && _threads.isEmpty
                ? const _LoadingList()
                : filtered.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25,
                      ),
                      Center(
                        child: Text(
                          query.isEmpty
                              ? 'No DMs yet.\nTap “New” to start one.'
                              : 'No results.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      final last = t.lastTs == null ? '—' : _fmtTime(t.lastTs!);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.surfaceContainerHigh,
                          child: const FaIcon(FontAwesomeIcons.user, size: 14),
                        ),
                        title: Text(
                          '@${t.peer}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Last active: $last'),
                        trailing: const FaIcon(
                          FontAwesomeIcons.chevronRight,
                          size: 14,
                        ),
                        onTap: () => _openDm(t.peer),
                      );
                    },
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
    final isToday =
        t.year == today.year && t.month == today.month && t.day == today.day;
    return isToday
        ? '$hh:$mm $ampm'
        : '${t.month}/${t.day}/${t.year.toString().substring(2)}';
  }
}

class _Thread {
  final String peer;
  final DateTime? lastTs;
  _Thread({required this.peer, required this.lastTs});
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: scheme.surfaceContainerHigh,
          child: const SizedBox.shrink(),
        ),
        title: Container(
          height: 12,
          width: double.infinity,
          margin: const EdgeInsets.only(right: 80),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        subtitle: Container(
          height: 10,
          width: 120,
          margin: const EdgeInsets.only(top: 6, right: 160),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
