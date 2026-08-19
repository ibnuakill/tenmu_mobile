import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';
import '../chat_ai_service.dart';
import '../chat_models.dart';

/// Bubble pesan chat (user kanan / bot kiri dengan avatar).
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ThemeProvider theme;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            _Avatar(emoji: ChatBotConfig.botAvatar, theme: theme),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? theme.btnPrimary : theme.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: message.isUser
                    ? null
                    : Border.all(color: theme.border.withValues(alpha: 0.3)),
              ),
              child: Text(
                ChatAIService.cleanMarkdown(message.text),
                style: TextStyle(
                  color: message.isUser ? theme.btnLabel : theme.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _Avatar(emoji: ChatBotConfig.userAvatar, theme: theme),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String emoji;
  final ThemeProvider theme;
  const _Avatar({required this.emoji, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
    );
  }
}

/// Indikator "AI sedang mengetik" (3 titik animasi statis).
class ChatTypingIndicator extends StatelessWidget {
  final ThemeProvider theme;
  const ChatTypingIndicator({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _Avatar(emoji: ChatBotConfig.botAvatar, theme: theme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(theme),
                const SizedBox(width: 4),
                _dot(theme),
                const SizedBox(width: 4),
                _dot(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(ThemeProvider theme) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: theme.textHint, shape: BoxShape.circle),
    );
  }
}
