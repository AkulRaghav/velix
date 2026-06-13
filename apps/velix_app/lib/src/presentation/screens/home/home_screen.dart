import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_domain/velix_domain.dart';

import '../../../di/providers.dart';
import '../../../router/app_router.dart';
import '../../components/identity_capsule.dart';

/// Home — mirrors the chats list but with a richer header. This IS the
/// primary surface since Velix is a messaging app.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.velix;
    final chats = ref.watch(chatListProvider).valueOrNull ?? [];

    return Container(
      color: v.colors.surface.substrate,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(v.space.gutterScreen, v.space.insetLg, v.space.gutterScreen, v.space.insetSm),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary)),
                      const SizedBox(height: 2),
                      Text('Velix', style: v.typography.displayS),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(Routes.settings),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: v.colors.surface.lifted,
                      ),
                      child: Icon(Icons.settings_rounded, size: 20, color: v.colors.text.secondary),
                    ),
                  ),
                ],
              ),
            ),
            // Quick stats
            Padding(
              padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen, vertical: v.space.insetSm),
              child: Row(
                children: [
                  _QuickStat(label: 'Conversations', value: '${chats.length}', color: v.colors.accent.signature),
                  SizedBox(width: v.space.insetMd),
                  _QuickStat(label: 'Unread', value: '${chats.fold<int>(0, (sum, c) => sum + c.unreadCount)}', color: v.colors.semantic.success),
                  SizedBox(width: v.space.insetMd),
                  _QuickStat(label: 'Encrypted', value: '✓', color: v.colors.accent.signature),
                ],
              ),
            ),
            SizedBox(height: v.space.insetSm),
            // Section label
            Padding(
              padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
              child: Text('RECENT CHATS', style: v.typography.labelS.copyWith(color: v.colors.text.tertiary, letterSpacing: 1)),
            ),
            SizedBox(height: v.space.insetSm),
            // Chat list
            Expanded(
              child: chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: v.colors.text.tertiary),
                          SizedBox(height: v.space.insetLg),
                          Text('No conversations yet', style: v.typography.titleS),
                          SizedBox(height: v.space.s3),
                          Text('Go to Chats tab to start messaging', style: v.typography.bodyM.copyWith(color: v.colors.text.tertiary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(bottom: v.space.s12 + 80),
                      itemCount: chats.length,
                      itemBuilder: (_, i) => _ChatTile(conversation: chats[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: v.space.insetMd, horizontal: v.space.insetSm),
        decoration: BoxDecoration(
          color: v.colors.surface.lifted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value, style: v.typography.titleM.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label, style: v.typography.labelS.copyWith(color: v.colors.text.tertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final c = conversation;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(Routes.chat(c.id)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen, vertical: 12),
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
                      Expanded(child: Text(c.title, style: v.typography.bodyL.copyWith(fontWeight: c.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(_time(c.lastActivityAt), style: v.typography.labelS.copyWith(color: c.unreadCount > 0 ? v.colors.accent.signature : v.colors.text.tertiary)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(c.lastMessagePreview ?? '', style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (c.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 20, height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: v.colors.accent.signature),
                alignment: Alignment.center,
                child: Text('${c.unreadCount}', style: v.typography.labelS.copyWith(color: v.colors.text.inverse, fontSize: 10)),
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
    return '${diff.inDays}d';
  }
}
