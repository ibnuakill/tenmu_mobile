/// Floating AI Chatbot — bubble pojok kanan + chat bottom sheet
///
/// Integrasi n8n webhook via [ChatBotConfig.webhookUrl].
library;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';

// ── Config ─────────────────────────────────────────────────────────
class ChatBotConfig {
  /// Ganti dengan URL webhook n8n lo nanti
  static const String webhookUrl = 'https://n8n.example.com/webhook/chat';
  static const String botName = 'AI Assistant';
  static const String botAvatar = '🤖';
  static const String userAvatar = '👤';
}

// ── Message Model ──────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();
}

// ── Floating Bubble ────────────────────────────────────────────────
class ChatBotBubble extends StatelessWidget {
  const ChatBotBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 16 + bottomPad, // aman dari navigasi HP
      right: 16,
      child: GestureDetector(
        onTap: () => _openChat(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.btnPrimary,
                theme.btnPrimary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.btnPrimary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: theme.btnLabel, size: 24),
              // Badge subtle "AI"
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.bgBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.btnPrimary, width: 1),
                  ),
                  child: Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: theme.btnPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChatBotSheet(),
    );
  }
}

// ── Chat Bottom Sheet ──────────────────────────────────────────────
class ChatBotSheet extends StatefulWidget {
  const ChatBotSheet({super.key});

  @override
  State<ChatBotSheet> createState() => _ChatBotSheetState();
}

class _ChatBotSheetState extends State<ChatBotSheet> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Halo! Saya AI asisten TenMu. Tanya rekomendasi tempat atau info lainnya, ya!',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      // Panggil n8n webhook
      final res = await http
          .post(
            Uri.parse(ChatBotConfig.webhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': text.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['reply'] ?? data['response'] ?? data['text'] ?? 'Maaf, saya tidak paham.';
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(text: reply, isUser: false));
            _isLoading = false;
          });
        }
      } else {
        _fallbackReply(text);
      }
    } catch (_) {
      _fallbackReply(text);
    }
  }

  void _fallbackReply(String userMsg) {
    // Fallback kalo n8n blm connect
    final replies = [
      'Wah, lagi ramai nih! Coba tanya lagi ya.',
      'Aku lagi mikir... Coba ulangi pertanyaannya!',
      'Maaf, aku belum bisa jawab sekarang. Nanti coba lagi!',
    ];
    final reply = replies[userMsg.length % replies.length];
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: theme.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ChatBotConfig.botName,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Online • Tanya rekomendasi tempat',
                        style: TextStyle(
                          color: theme.btnPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: theme.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: theme.border, height: 1),

          // ── Messages ────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👋', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'Mulai diskusi dengan AI',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _TypingIndicator(theme: theme);
                      }
                      return _MessageBubble(
                        message: _messages[index],
                        theme: theme,
                      );
                    },
                  ),
          ),

          // ── Input ───────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset + (bottomPad > 0 ? bottomPad : 12)),
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
                      controller: _inputController,
                      enabled: !_isLoading,
                      style: TextStyle(color: theme.textPrimary, fontSize: 14),
                      cursorColor: theme.borderFocus,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_isLoading ? null : _sendMessage),
                      decoration: InputDecoration(
                        hintText: 'Tanya rekomendasi tempat...',
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
                  onTap: () => _sendMessage(_inputController.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _inputController.text.trim().isEmpty && !_isLoading
                          ? theme.bgElevated
                          : theme.btnPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.btnLabel,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: _inputController.text.trim().isEmpty
                                ? theme.textHint
                                : theme.btnLabel,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ThemeProvider theme;

  const _MessageBubble({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(ChatBotConfig.botAvatar, style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                message.text,
                style: TextStyle(
                  color: message.isUser ? theme.btnLabel : theme.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
          if (message.isUser)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(ChatBotConfig.userAvatar, style: TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  final ThemeProvider theme;
  const _TypingIndicator({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(ChatBotConfig.botAvatar, style: TextStyle(fontSize: 14)),
            ),
          ),
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
      decoration: BoxDecoration(
        color: theme.textHint,
        shape: BoxShape.circle,
      ),
    );
  }
}
