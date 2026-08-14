import 'package:flutter/material.dart';
import '../main.dart' show chatbotNavigatorKey;
import '../services/chatbot_visibility_service.dart';
import '../theme/app_theme.dart';
import 'chatbot_chat_sheet.dart';
import 'chatbot_tour_guide_logo.dart';

/// The IntraBadi assistant's entry point (chatbot spec Section 1): "a
/// toggleable side icon, visible on every page of the app — not a fixed
/// floating bubble that's always sitting on-screen. The user can
/// show/hide it themselves (e.g., a small tab or handle on the side of
/// the screen that expands into the chat button when tapped, and can be
/// collapsed/hidden again when not needed)."
///
/// Two visual states, both docked to the right edge:
/// - **Collapsed**: a slim vertical tab/handle the user taps to reveal
///   the full chat button.
/// - **Expanded**: the full round chat icon button, with a small
///   collapse affordance to hide it again.
///
/// Shown/hidden state is read from [ChatbotVisibilityService], which
/// persists across page navigation and app restarts, per spec. This
/// widget only controls the *collapsed vs. expanded* presentation of the
/// handle itself (a lighter-weight, transient UI detail) — it always
/// listens to the service for the underlying shown/hidden preference.
class ChatbotSideHandle extends StatefulWidget {
  const ChatbotSideHandle({super.key});

  @override
  State<ChatbotSideHandle> createState() => _ChatbotSideHandleState();
}

class _ChatbotSideHandleState extends State<ChatbotSideHandle> {
  bool _expanded = false;

  void _openChat() {
    // `context` here has no Navigator ancestor: this widget is
    // deliberately mounted in `MaterialApp.builder`, above/outside the
    // Navigator's subtree (see main.dart), so it persists across page
    // push/pop instead of being rebuilt. Use the app-wide
    // `chatbotNavigatorKey` to reach a context that *does* sit inside
    // the Navigator, so `showModalBottomSheet` (called from
    // `showChatbotChatSheet`) can find it via `Navigator.of(context)`.
    final navigatorContext = chatbotNavigatorKey.currentState?.context;
    if (navigatorContext == null) return;
    showChatbotChatSheet(navigatorContext);
  }

  void _hideHandleEntirely() {
    ChatbotVisibilityService.instance.setVisible(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: ChatbotVisibilityService.instance,
      builder: (context, _) {
        if (!ChatbotVisibilityService.instance.isVisible) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 0,
          bottom: 140,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
            child: _expanded
                ? _ExpandedHandle(
                    key: const ValueKey('expanded'),
                    colors: colors,
                    onOpenChat: _openChat,
                    onCollapse: () => setState(() => _expanded = false),
                    onHide: _hideHandleEntirely,
                  )
                : _CollapsedTab(
                    key: const ValueKey('collapsed'),
                    colors: colors,
                    onTap: () => setState(() => _expanded = true),
                  ),
          ),
        );
      },
    );
  }
}

/// The slim, mostly-off-screen tab shown when the handle is collapsed.
/// Tapping it reveals the full chat button ([_ExpandedHandle]).
class _CollapsedTab extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onTap;

  const _CollapsedTab({super.key, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        child: Container(
          width: 26,
          height: 56,
          decoration: BoxDecoration(
            color: colors.forest,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(-1, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// The full round chat-launcher button, shown once the user taps the
/// collapsed tab. Tapping the icon opens the chat window; the small
/// secondary control lets the user collapse the handle back down or hide
/// it entirely, per spec.
class _ExpandedHandle extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onOpenChat;
  final VoidCallback onCollapse;
  final VoidCallback onHide;

  const _ExpandedHandle({
    super.key,
    required this.colors,
    required this.onOpenChat,
    required this.onCollapse,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse-back-to-tab control, kept small/secondary since the
          // main action on this handle is opening the chat, not hiding it.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCollapse,
              customBorder: const CircleBorder(),
              onLongPress: onHide,
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: colors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.line),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: colors.muted,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            elevation: 4,
            shape: const CircleBorder(),
            shadowColor: Colors.black.withValues(alpha: 0.25),
            child: InkWell(
              onTap: onOpenChat,
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.forest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const ChatbotTourGuideLogo(size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
