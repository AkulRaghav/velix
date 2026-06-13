import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_domain/velix_domain.dart';

import '../../../di/providers.dart';
import '../../components/identity_capsule.dart';
import '../../components/message_bubble.dart';

/// ChatScreen â€” Tier A. The largest single screen.
///
/// Phase 9 perf posture (F3, F4):
/// - Composer state lives in a [ValueNotifier]; the message list never
///   rebuilds on keystroke.
/// - Header is a `const`-friendly stateless widget reading conversation via
///   its own [ConsumerWidget] so screen-level rebuilds don't cascade.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final ConversationId conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  final _draft = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerChanged);
  }

  void _onComposerChanged() {
    if (_draft.value != _composer.text) {
      _draft.value = _composer.text;
    }
  }

  @override
  void dispose() {
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.substrate,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(conversationId: widget.conversationId),
            Expanded(child: _MessageList(conversationId: widget.conversationId)),
            _SmartReplies(onSelect: (text) {
              _composer.text = text;
              _draft.value = text;
              _send();
            },),
            _Composer(
              controller: _composer,
              focusNode: _composerFocus,
              draft: _draft,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    _composer.clear();
    _draft.value = '';
    final res = await ref.read(sendMessageProvider).call(
          conversationId: widget.conversationId,
          body: body,
        );
    if (res.isErr && mounted) {
      // Phase 7+: route through error reporter.
      _composer.text = body;
      _draft.value = body;
    }
  }
}

/// Per Phase 9 F1: the message list is its own [ConsumerWidget]. It watches
/// `messagesProvider(id)` and `identityProvider`. Composer changes never
/// touch this widget.
class _MessageList extends ConsumerWidget {
  const _MessageList({required this.conversationId});

  final ConversationId conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.velix;
    final me = ref.watch(identityProvider).valueOrNull;
    final messages = ref.watch(messagesProvider(conversationId));
    final conv = ref.watch(conversationProvider(conversationId)).valueOrNull;

    return messages.when(
      data: (msgs) => ListView.builder(
        padding: EdgeInsets.only(top: v.space.insetMd, bottom: v.space.s9),
        itemCount: msgs.length,
        itemBuilder: (context, i) {
          final m = msgs[i];
          final isOutgoing = me != null && m.senderId == me.id;
          return RepaintBoundary(
            key: ValueKey<MessageId>(m.id),
            child: MessageBubble(
              message: m,
              isOutgoing: isOutgoing,
              roomColorIndex: conv?.roomColorIndex ?? 0,
            ),
          );
        },
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.conversationId});

  final ConversationId conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.velix;
    final conversation =
        ref.watch(conversationProvider(conversationId)).valueOrNull;
    return Container(
      padding: EdgeInsets.fromLTRB(
        v.space.gutterList,
        v.space.insetMd,
        v.space.gutterList,
        v.space.insetMd,
      ),
      decoration: BoxDecoration(
        color: v.colors.surface.substrate,
        border: Border(
          bottom: BorderSide(color: v.colors.text.primary.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                '\u2039',
                style: v.typography.titleL.copyWith(color: v.colors.text.primary),
              ),
            ),
          ),
          SizedBox(width: v.space.insetSm),
          Stack(
            children: [
              IdentityCapsule(
                title: conversation?.title ?? '',
                size: IdentityCapsuleSize.md,
                roomColorIndex: conversation?.roomColorIndex,
                presence: false,
              ),
              // Online indicator dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: v.colors.semantic.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: v.colors.surface.substrate, width: 2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: v.space.insetMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  conversation?.title ?? '',
                  style: v.typography.titleS,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  conversation?.trustState == TrustState.verified
                      ? 'Online \u2022 Encrypted'
                      : 'Online',
                  style: v.typography.bodyS.copyWith(
                    color: v.colors.semantic.success,
                  ),
                ),
              ],
            ),
          ),
          // Call button
          Container(
            width: 36,
            height: 36,
            margin: EdgeInsets.only(right: v.space.insetSm),
            decoration: BoxDecoration(
              color: v.colors.surface.lifted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('📞', style: v.typography.bodyM),
          ),
          // Video button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: v.colors.surface.lifted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('📹', style: v.typography.bodyM),
          ),
        ],
      ),
    );
  }
}

/// AI-generated smart reply suggestions. Contextual chips that send instantly.
class _SmartReplies extends StatelessWidget {
  const _SmartReplies({required this.onSelect});
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: v.space.gutterList, vertical: 6),
      child: Row(
        children: [
          _ReplyChip(text: 'Sounds great! 👍', onTap: () => onSelect('Sounds great! 👍')),
          SizedBox(width: v.space.insetSm),
          _ReplyChip(text: 'On my way', onTap: () => onSelect('On my way')),
          SizedBox(width: v.space.insetSm),
          _ReplyChip(text: 'Can we reschedule?', onTap: () => onSelect('Can we reschedule?')),
        ],
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: v.space.insetMd, vertical: v.space.insetSm),
        decoration: BoxDecoration(
          border: Border.all(color: v.colors.accent.signature.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
          color: v.colors.accent.signature.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✦ ', style: v.typography.labelS.copyWith(color: v.colors.accent.signature)),
            Text(text, style: v.typography.bodyS.copyWith(color: v.colors.text.primary)),
          ],
        ),
      ),
    );
  }
}

/// Composer with attachment + emoji buttons, matching the Figma reference.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.draft,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueListenable<String> draft;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      padding: EdgeInsets.fromLTRB(
        v.space.gutterList,
        v.space.insetSm,
        v.space.gutterList,
        MediaQuery.of(context).viewInsets.bottom + v.space.insetMd,
      ),
      decoration: BoxDecoration(
        color: v.colors.surface.substrate,
        border: Border(
          top: BorderSide(color: v.colors.text.primary.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: v.colors.surface.lifted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('📎', style: v.typography.bodyM),
          ),
          SizedBox(width: v.space.insetSm),
          // Input field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: v.colors.surface.lifted,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: EditableText(
                      controller: controller,
                      focusNode: focusNode,
                      cursorColor: v.colors.accent.signature,
                      backgroundCursorColor: v.colors.text.tertiary,
                      style: v.typography.bodyL,
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  // Emoji button
                  Text('😊', style: v.typography.bodyL),
                ],
              ),
            ),
          ),
          SizedBox(width: v.space.insetSm),
          // Send button with gradient
          ValueListenableBuilder<String>(
            valueListenable: draft,
            builder: (context, value, _) {
              final canSend = value.trim().isNotEmpty;
              return GestureDetector(
                onTap: canSend ? onSend : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: canSend
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [v.colors.accent.s30, v.colors.accent.signature],
                          )
                        : null,
                    color: canSend ? null : v.colors.surface.lifted,
                    boxShadow: canSend
                        ? [
                            BoxShadow(
                              color: v.colors.accent.signature.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '\u2191',
                    style: v.typography.titleS.copyWith(
                      color: canSend ? v.colors.text.inverse : v.colors.text.tertiary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
