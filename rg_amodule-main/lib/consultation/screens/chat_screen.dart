import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/consultation_controller.dart';
import '../models/consultation_session.dart';
import '../providers/consultation_provider.dart';

// ── Chat Screen ───────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.session});
  final ConsultationSession session;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Re-sync the session timer from Supabase after the app resumes from background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(sessionProvider(widget.session).notifier)
          .syncFromServer();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    ref.read(sessionProvider(widget.session).notifier).sendMessage(
          text,
          widget.session.userId,
          widget.session.userName,
        );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider(widget.session));
    final ctrl = ref.read(sessionProvider(widget.session).notifier);

    // Auto-scroll when messages change
    ref.listen<SessionState>(sessionProvider(widget.session), (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.isPanditTyping != next.isPanditTyping) {
        _scrollToBottom();
      }
    });

    final isExpired = sessionState.isEnded || sessionState.chatLocked;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEndSession(context, ctrl);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────
            _ChatAppBar(
              session: widget.session,
              sessionState: sessionState,
              onEndTap: () => _confirmEndSession(context, ctrl),
            ),

            // ── 1-minute warning banner ──────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: sessionState.showWarning ? null : 0,
              child: sessionState.showWarning
                  ? _WarningBanner(
                      onExtend: () =>
                          _showExtendSheet(context, ctrl),
                    )
                  : null,
            ),

            // ── Messages ──────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  _MessagesList(
                    scrollCtrl: _scrollCtrl,
                    sessionState: sessionState,
                    selfId: widget.session.userId,
                  ),
                  // Connecting overlay
                  if (sessionState.isConnecting)
                    _ConnectingOverlay(
                        panditName: widget.session.pandit.name),
                  // Expired overlay
                  if (isExpired && sessionState.isEnded)
                    _ExpiredOverlay(
                      onExtend: sessionState.session.status ==
                              SessionStatus.expired
                          ? () => _showExtendSheet(context, ctrl)
                          : null,
                      onLeave: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),

            // ── Input bar ─────────────────────────────────────────────────
            _ChatInputBar(
              controller: _textCtrl,
              hasText: _hasText,
              locked: isExpired,
              onSend: _sendMessage,
              onExtend: isExpired
                  ? () => _showExtendSheet(context, ctrl)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEndSession(
      BuildContext context, SessionController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('End Session?'),
        content: const Text(
            'Are you sure you want to end this consultation session? '
            'Unused time will not be refunded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.endSession().then((_) {
                if (context.mounted) Navigator.of(context).pop();
              });
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  void _showExtendSheet(BuildContext ctx, SessionController ctrl) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExtendSessionSheet(ctrl: ctrl),
    );
  }
}

// ── Custom App Bar ────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({
    required this.session,
    required this.sessionState,
    required this.onEndTap,
  });
  final ConsultationSession session;
  final SessionState sessionState;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    final timerColor = sessionState.showWarning
        ? AppColors.warning
        : sessionState.isEnded
            ? AppColors.error
            : Colors.white;

    return Material(
      color: AppColors.secondary,
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Back
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: onEndTap,
                  ),
                  // Pandit avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withAlpha(30),
                    child: Text(
                      session.pandit.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Pandit name + specialty
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.pandit.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5),
                        ),
                        Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle)),
                          Text(
                            sessionState.isConnecting
                                ? 'Connecting…'
                                : sessionState.isEnded
                                    ? 'Session ended'
                                    : session.pandit.specialty,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  // Countdown timer
                  if (!sessionState.isConnecting) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          sessionState.formattedRemaining,
                          style: TextStyle(
                              color: timerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        Text(
                          'remaining',
                          style: TextStyle(
                              color: timerColor.withAlpha(180),
                              fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  // End session button
                  if (!sessionState.isEnded)
                    IconButton(
                      icon: const Icon(Icons.call_end_rounded,
                          color: AppColors.error),
                      onPressed: onEndTap,
                      tooltip: 'End Session',
                    ),
                ],
              ),
            ),
          ),
          // Timer progress bar
          if (!sessionState.isConnecting)
            _TimerProgressBar(
              progress: sessionState.timerProgress,
              warning: sessionState.showWarning,
              expired: sessionState.isEnded,
            ),
        ],
      ),
    );
  }
}

class _TimerProgressBar extends StatelessWidget {
  const _TimerProgressBar({
    required this.progress,
    required this.warning,
    required this.expired,
  });
  final double progress;
  final bool warning;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final color = expired
        ? AppColors.error
        : warning
            ? AppColors.warning
            : AppColors.secondaryLight;

    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withAlpha(20),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 3,
      ),
    );
  }
}

// ── Warning Banner ────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.onExtend});
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.warning.withAlpha(240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '1 minute remaining! Extend to keep chatting.',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: onExtend,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: Colors.white.withAlpha(40),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Extend',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ── Messages List ─────────────────────────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.scrollCtrl,
    required this.sessionState,
    required this.selfId,
  });
  final ScrollController scrollCtrl;
  final SessionState sessionState;
  final String selfId;

  @override
  Widget build(BuildContext context) {
    final messages = sessionState.messages;

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length + (sessionState.isPanditTyping ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Typing indicator as last item
        if (i == messages.length) {
          return const _TypingIndicatorBubble();
        }

        final msg = messages[i];

        // System message
        if (msg.isSystem) {
          return _SystemMessage(text: msg.text);
        }

        final isMe = msg.senderId == selfId;
        return _MessageBubble(message: msg, isMe: isMe);
      },
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pandit avatar
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondary.withAlpha(20),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isMe ? 18 : 4),
                      bottomRight:
                          Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                        color: isMe ? Colors.white : null,
                        fontSize: 14.5),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmtTime(message.sentAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant
                          .withAlpha(140)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── System Message ────────────────────────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() =>
      _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState
    extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _dotAnims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat();

    _dotAnims = List.generate(3, (i) {
      final start = i * 0.2;
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, start + 0.4,
              curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.secondary.withAlpha(20),
            child: const Text('P',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Transform.translate(
                    offset: Offset(0, _dotAnims[i].value),
                    child: Container(
                      margin:
                          EdgeInsets.only(right: i < 2 ? 4 : 0),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary
                            .withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Input Bar ────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.hasText,
    required this.locked,
    required this.onSend,
    this.onExtend,
  });
  final TextEditingController controller;
  final bool hasText;
  final bool locked;
  final VoidCallback onSend;
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: locked
            ? _LockedInputBar(onExtend: onExtend)
            : Row(
                children: [
                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      child: TextField(
                        controller: controller,
                        textCapitalization:
                            TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type your message…',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child: InkWell(
                      onTap: hasText ? onSend : null,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasText
                              ? AppColors.primary
                              : cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: hasText
                              ? Colors.white
                              : AppColors.textHint,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LockedInputBar extends StatelessWidget {
  const _LockedInputBar({this.onExtend});
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: AppColors.error.withAlpha(60)),
            ),
            child: const Row(children: [
              Icon(Icons.lock_rounded,
                  color: AppColors.error, size: 16),
              SizedBox(width: 8),
              Text('Session expired — chat locked',
                  style: TextStyle(
                      color: AppColors.error, fontSize: 13.5)),
            ]),
          ),
        ),
        if (onExtend != null) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onExtend,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            child: const Text('Extend',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

// ── Connecting Overlay ────────────────────────────────────────────────────────

class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay({required this.panditName});
  final String panditName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withAlpha(230),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Connecting to $panditName…',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Setting up your secure session',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

// ── Expired Overlay ───────────────────────────────────────────────────────────

class _ExpiredOverlay extends StatelessWidget {
  const _ExpiredOverlay({this.onExtend, required this.onLeave});
  final VoidCallback? onExtend;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color:
          Theme.of(context).colorScheme.surface.withAlpha(215),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Session Ended',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            const Text(
                'Your consultation session has ended.\nChat messages are now locked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14)),
            const SizedBox(height: 28),
            if (onExtend != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onExtend,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Extend Session (+10 min)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onLeave,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Back to Consultants'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extend Session Bottom Sheet ───────────────────────────────────────────────

class _ExtendSessionSheet extends StatelessWidget {
  const _ExtendSessionSheet({required this.ctrl});
  final SessionController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Extend Session',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
              'Add 10 more minutes to your current session.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 20),
          // Extension option card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primary.withAlpha(12),
              ),
              child: const Row(children: [
                Icon(Icons.add_alarm_rounded,
                    color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+10 Minutes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary)),
                      Text('Continue your consultation',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹99',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary)),
                    Text('(₹9.9/min)',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textHint),
                SizedBox(width: 4),
                Text(
                  'Payment gateway integration pending.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ctrl.requestExtension(addMinutes: 10);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Extend for ₹99',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


