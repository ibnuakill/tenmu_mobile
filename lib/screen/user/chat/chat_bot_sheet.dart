import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import 'chat_ai_service.dart';
import 'chat_models.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_history_sheet.dart';
import 'widgets/chat_search_results.dart';
import 'widgets/message_bubble.dart';

/// Chat bottom sheet — state percakapan + komposisi UI.
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
  List<Map<String, dynamic>> _searchResults = [];

  // Edge Function (server-side AI) ready?
  bool _aiReady = false;

  // Riwayat sesi + sesi aktif (null = sesi baru belum tersimpan).
  List<ChatSession> _sessions = [];
  String? _sessionId;

  static const String _welcome =
      'Halo! Aku TenMu AI 🌟\nTanya apa aja — rekomendasi tempat, tips, atau obrolan santai!';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Muat riwayat sesi; lanjutkan sesi terbaru, welcome hanya bila kosong.
      final sessions = await ChatAIService.loadSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        if (sessions.isNotEmpty) {
          final latest = sessions.first;
          _sessionId = latest.id;
          _messages.addAll(latest.messages);
        } else {
          _messages.add(ChatMessage(text: _welcome, isUser: false));
        }
      });
      _aiReady = await ChatAIService.ping();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    final userText = text.trim();

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isLoading = true;
      _searchResults = [];
    });
    _inputController.clear();
    _scrollToBottom();

    String reply;

    if (_aiReady) {
      try {
        final result = await ChatAIService.callEdgeAi(userText, _messages);
        reply = result.reply;
        if (!mounted) return;
        _aiReady = true; // self-heal: sukses berarti fungsi AI hidup
        if (result.mentioned.isNotEmpty) {
          setState(() => _searchResults = result.mentioned);
        }
      } catch (e) {
        debugPrint('Edge AI error: $e');
        // Gagal → fallback lokal (AI mungkin mati; ping ulang nanti).
        _aiReady = false;
        if (!mounted) return;
        final fallback = ChatAIService.localSearch(context, userText);
        reply = fallback.reply;
        if (mounted && fallback.results.isNotEmpty) {
          setState(() => _searchResults = fallback.results);
        }
      }
    } else {
      final fallback = ChatAIService.localSearch(context, userText);
      reply = fallback.reply;
      if (mounted && fallback.results.isNotEmpty) {
        setState(() => _searchResults = fallback.results);
      }
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
      _persistSession(); // simpan sesi (fire-and-forget)
    }
  }

  /// Simpan percakapan saat ini sebagai satu sesi riwayat.
  Future<void> _persistSession() async {
    final id = _sessionId ?? DateTime.now().microsecondsSinceEpoch.toString();
    _sessionId = id;
    final session = ChatSession(
      id: id,
      updatedAt: DateTime.now(),
      messages: List.of(_messages),
    );
    await ChatAIService.saveSession(session);
    final sessions = await ChatAIService.loadSessions();
    if (mounted) setState(() => _sessions = sessions);
  }

  // ── Riwayat chat: lihat / buka / baru / hapus ──────────

  Future<void> _openHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChatHistorySheet(
        sessions: _sessions,
        onNewChat: _startNewChat,
        onOpen: _openSession,
        onDelete: _confirmDeleteSession,
      ),
    );
  }

  void _openSession(ChatSession session) {
    setState(() {
      _messages
        ..clear()
        ..addAll(session.messages);
      _sessionId = session.id;
      _searchResults = [];
    });
    _scrollToBottom();
  }

  void _startNewChat() {
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(text: _welcome, isUser: false));
      _sessionId = null; // sesi baru: belum tersimpan
      _searchResults = [];
    });
    _scrollToBottom();
  }

  Future<void> _confirmDeleteSession(ChatSession session) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgSurface,
        title: const Text('Hapus riwayat chat ini?'),
        content: const Text('Percakapan sesi ini akan dihapus dari perangkat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ChatAIService.deleteSession(session.id);
    final sessions = await ChatAIService.loadSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      // Sesi aktif yang dihapus → kembali ke awal.
      if (_sessionId == session.id) {
        _sessionId = null;
        _messages
          ..clear()
          ..add(ChatMessage(text: _welcome, isUser: false));
        _searchResults = [];
      }
    });
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: theme.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _SheetHandle(theme: theme),
          _ChatHeader(theme: theme, onHistory: _openHistory),
          Divider(color: theme.border, height: 1),
          Expanded(child: _buildMessageList(theme)),
          if (_searchResults.isNotEmpty)
            ChatSearchResults(results: _searchResults, theme: theme),
          ChatInputBar(
            theme: theme,
            controller: _inputController,
            isLoading: _isLoading,
            onSend: _sendMessage,
            onSendPressed: () => _sendMessage(_inputController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeProvider theme) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👋', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              'Mulai diskusi dengan AI',
              style: TextStyle(color: theme.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return ChatTypingIndicator(theme: theme);
        }
        return ChatMessageBubble(message: _messages[index], theme: theme);
      },
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final ThemeProvider theme;
  const _SheetHandle({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final ThemeProvider theme;
  final VoidCallback onHistory;
  const _ChatHeader({required this.theme, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  'Online • Asisten TenMu',
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
            onTap: onHistory,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: theme.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: theme.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}