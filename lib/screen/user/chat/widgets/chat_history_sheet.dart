import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';
import '../chat_models.dart';

/// Bottom sheet daftar riwayat chat — user bisa LIHAT & buka lagi sesi lama.
class ChatHistorySheet extends StatefulWidget {
  final List<ChatSession> sessions;
  final VoidCallback onNewChat;
  final void Function(ChatSession) onOpen;
  final Future<void> Function(ChatSession) onDelete;

  const ChatHistorySheet({
    super.key,
    required this.sessions,
    required this.onNewChat,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<ChatHistorySheet> createState() => _ChatHistorySheetState();
}

class _ChatHistorySheetState extends State<ChatHistorySheet> {
  // Salinan lokal agar daftar ikut ter-update saat satu sesi dihapus.
  late final List<ChatSession> _sessions = List.of(widget.sessions);

  Future<void> _delete(ChatSession session) async {
    await widget.onDelete(session);
    if (!mounted) return;
    setState(() => _sessions.removeWhere((s) => s.id == session.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
            child: Row(
              children: [
                Text(
                  'Riwayat Chat',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onNewChat();
                  },
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Chat Baru'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.btnPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                ),
              ],
            ),
          ),
          Divider(color: theme.border, height: 1),
          Expanded(
            child: _sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada riwayat chat',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = _sessions[index];
                      return _SessionTile(
                        session: s,
                        theme: theme,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpen(s);
                        },
                        onDelete: () => _delete(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final ThemeProvider theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.theme,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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
                    session.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.messages.length} pesan • ${session.timeLabel}',
                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}