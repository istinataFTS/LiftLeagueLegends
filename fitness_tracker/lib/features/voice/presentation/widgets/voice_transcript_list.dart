import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/voice_message.dart';
import '../voice_overlay_keys.dart';

/// Scrollable chat-style list of conversation turns.
///
/// The last item auto-scrolls into view whenever [messages] or
/// [liveTranscript] changes. A "pending" bubble is appended while the
/// user's live transcript is in progress.
class VoiceTranscriptList extends StatefulWidget {
  const VoiceTranscriptList({
    required this.messages,
    this.liveTranscript,
    super.key,
  });

  final List<VoiceMessage> messages;

  /// Partial transcript currently being captured by STT.
  /// Null when STT is not active.
  final String? liveTranscript;

  @override
  State<VoiceTranscriptList> createState() => _VoiceTranscriptListState();
}

class _VoiceTranscriptListState extends State<VoiceTranscriptList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(VoiceTranscriptList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages ||
        oldWidget.liveTranscript != widget.liveTranscript) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLive =
        widget.liveTranscript != null && widget.liveTranscript!.isNotEmpty;
    final int itemCount = widget.messages.length + (hasLive ? 1 : 0);

    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      key: VoiceOverlayKeys.transcriptListKey,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Live transcript pending bubble
        if (hasLive && index == itemCount - 1) {
          return _TranscriptBubble(
            text: widget.liveTranscript!,
            isUser: true,
            isPending: true,
          );
        }
        final VoiceMessage msg = widget.messages[index];
        return _TranscriptBubble(
          text: msg.content,
          isUser: msg.role == VoiceRole.user,
          isPending: false,
        );
      },
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({
    required this.text,
    required this.isUser,
    required this.isPending,
  });

  final String text;
  final bool isUser;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = isUser
        ? AppTheme.primaryOrange.withAlpha(38)
        : AppTheme.surfaceMedium;
    final Color textColor = isPending ? AppTheme.textDim : AppTheme.textLight;
    final CrossAxisAlignment alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final BorderRadius radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              border: isUser
                  ? Border.all(color: AppTheme.primaryOrange.withAlpha(76))
                  : null,
            ),
            child: isPending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const _PendingDots(),
                    ],
                  )
                : Text(text, style: TextStyle(color: textColor, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _PendingDots extends StatefulWidget {
  const _PendingDots();

  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final int frame = (_controller.value * 3).floor();
        return Text(
          '.' * (frame + 1),
          style: const TextStyle(
            color: AppTheme.textDim,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}
