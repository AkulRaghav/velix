import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_data/velix_data.dart';
import 'package:velix_domain/velix_domain.dart';

import '../../../di/providers.dart';
import '../../../router/app_router.dart';
import '../../components/identity_capsule.dart';

/// Chats â€” the core screen. Dense, responsive, functional.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(chatListProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newConversation(context),
        backgroundColor: const Color(0xFF3478F6),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header + search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Messages', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 14),
                  // Search
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 18, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search conversations',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: list.when(
                data: (cs) {
                  final filtered = _query.isEmpty ? cs : cs.where((c) => c.title.toLowerCase().contains(_query.toLowerCase())).toList();
                  if (cs.isEmpty) return _EmptyState(onCompose: () => _newConversation(context));
                  if (filtered.isEmpty) return Center(child: Text('No results for "$_query"', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))));
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, indent: 76, color: Colors.white.withValues(alpha: 0.04)),
                    itemBuilder: (_, i) => _ConversationTile(conversation: filtered[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => Center(child: Text('Connection error', style: TextStyle(color: Colors.white.withValues(alpha: 0.4)))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newConversation(BuildContext context) async {
    final ctl = TextEditingController();
    final handle = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Enter a username to start chatting', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 20),
            TextField(
              controller: ctl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Username (e.g. sarah)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3478F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start chat', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (handle == null || handle.isEmpty) return;
    if (!mounted) return;
    final boot = ref.read(bootstrapProvider);
    final client = boot.alphaApiClient;
    try {
      final user = await client.lookup(handle: handle);
      final repo = boot.conversationRepository;
      if (repo is RemoteConversationRepository) {
        final conv = await repo.openWith(peerAccountId: user.accountId, title: handle);
        if (!mounted) return;
        context.push(Routes.chat(conv.id));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User "$handle" not found')));
    }
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return InkWell(
      onTap: () => context.push(Routes.chat(c.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            IdentityCapsule(title: c.title, roomColorIndex: c.roomColorIndex, size: IdentityCapsuleSize.md),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          style: TextStyle(fontSize: 15, fontWeight: c.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_time(c.lastActivityAt), style: TextStyle(fontSize: 12, color: c.unreadCount > 0 ? const Color(0xFF3478F6) : Colors.white.withValues(alpha: 0.35))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.lastMessagePreview ?? 'No messages yet',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: c.unreadCount > 0 ? 0.7 : 0.35)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 20, height: 20,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3478F6)),
                          alignment: Alignment.center,
                          child: Text('${c.unreadCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(Instant t) {
    final diff = DateTime.now().difference(t.toDateTime().toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final dt = t.toDateTime().toLocal();
    return '${dt.month}/${dt.day}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCompose});
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_rounded, size: 56, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 20),
          const Text('No conversations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Start a new chat to get going', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCompose,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3478F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
