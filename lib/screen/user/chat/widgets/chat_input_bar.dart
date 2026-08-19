import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';

/// Input bar chat: text field + tombol kirim (loading state).
class ChatInputBar extends StatelessWidget {
  final ThemeProvider theme;
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSend;
  final VoidCallback onSendPressed;

  const ChatInputBar({
    super.key,
    required this.theme,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onSendPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + bottomInset + (bottomPad > 0 ? bottomPad : 12),
      ),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                style: TextStyle(color: theme.textPrimary, fontSize: 14),
                cursorColor: theme.borderFocus,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: isLoading ? null : onSend,
                decoration: InputDecoration(
                  hintText: 'Tanya apa aja...',
                  hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSendPressed,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: controller.text.trim().isEmpty && !isLoading
                    ? theme.bgElevated
                    : theme.btnPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.btnLabel,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: controller.text.trim().isEmpty
                          ? theme.textHint
                          : theme.btnLabel,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
