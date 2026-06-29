/// Floating AI Chatbot — bubble pojok kanan + chat bottom sheet
///
/// Search lokal dari [PlacesProvider] — filter nama/deskripsi/kategori tempat.
/// Hasil tappable → navigasi ke [PoiDetailScreen].
library;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/places_provider.dart';
import '../../../core/poi_image_helper.dart' show PoiImageHelper;
import '../poi_detail_screen.dart';

// ── Config ─────────────────────────────────────────────────────────
class ChatBotConfig {
  static const String botName = 'TenMu AI';
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
  List<Map<String, dynamic>> _searchResults = [];

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

    // Search langsung dari PlacesProvider
    final provider = context.read<PlacesProvider>();
    if (provider.placesList.isEmpty) {
      await provider.fetchPlaces();
    }

    final query = text.trim().toLowerCase();
    final results = provider.placesList.where((p) {
      final nama = (p['nama_tempat']?.toString() ?? '').toLowerCase();
      final deskripsi = (p['deskripsi']?.toString() ?? '').toLowerCase();
      final category = (p['category']?.toString() ?? '').toLowerCase();
      final fasilitas = (p['fasilitas']?.toString() ?? '').toLowerCase();
      return nama.contains(query) ||
          deskripsi.contains(query) ||
          category.contains(query) ||
          fasilitas.contains(query);
    }).toList();

    String reply;
    if (results.isEmpty) {
      reply = 'Maaf, ga nemu tempat yang cocok dengan "$text". Coba keyword lain ya!';
    } else if (results.length == 1) {
      final p = results.first;
      reply = 'Ketemu 1 tempat:\n${p['nama_tempat']}\n📍 ${p['alamat'] ?? ''}';
    } else {
      final sb = StringBuffer('Ketemu ${results.length} tempat:\n');
      for (var i = 0; i < results.length && i < 5; i++) {
        sb.writeln('${i + 1}. ${results[i]['nama_tempat']}');
      }
      if (results.length > 5) {
        sb.writeln('...dan ${results.length - 5} lainnya.');
      }
      sb.write('\nTap pilihan di bawah buat lihat detail!');
      reply = sb.toString();
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();

      // Kalo ada hasil, tampilin kartu tempat
      if (results.isNotEmpty) {
        setState(() {
          _searchResults = results.take(5).toList();
        });
      }
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

          // ── Search Result Cards ─────────────────────────────
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                border: Border(top: BorderSide(color: theme.border)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: theme.border.withValues(alpha: 0.3)),
                itemBuilder: (context, i) {
                  final place = _searchResults[i];
                  final name = place['nama_tempat'] ?? '';
                  final alamat = place['alamat'] ?? '';
                  final imgUrl = PoiImageHelper.primaryImageUrl(place);
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PoiDetailScreen(place: place),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imgUrl != null
                                ? Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover)
                                : Container(
                                    width: 48, height: 48,
                                    color: theme.bgElevated,
                                    child: Icon(Icons.image_outlined, color: theme.textHint, size: 20),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(
                                  color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(alamat, style: TextStyle(
                                  color: theme.textSecondary, fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: theme.textHint, size: 18),
                        ],
                      ),
                    ),
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
