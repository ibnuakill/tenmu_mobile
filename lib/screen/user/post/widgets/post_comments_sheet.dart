import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme_provider.dart';
import '../post_models.dart';
import '../post_provider.dart';
import '../../../../core/lucide_icons.dart';

/// Bottom sheet daftar komentar sebuah postingan + input komentar baru.
class PostCommentsSheet extends StatefulWidget {
  final PlacePost post;

  const PostCommentsSheet({super.key, required this.post});

  static Future<void> show(BuildContext context, PlacePost post) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PostCommentsSheet(post: post),
    );
  }

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final _ctrl = TextEditingController();
  final _provider = PostProvider();
  List<PostComment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await fetchPostComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final err = await _provider.addComment(widget.post.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    _ctrl.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isAuth = Supabase.instance.client.auth.currentUser != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  LucideIcon('message-square',
                      color: theme.textPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Komentar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_comments.length}',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.divider),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.btnPrimary))
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada komentar.\nJadi yang pertama berkomentar!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _comments.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, i) =>
                              _commentTile(_comments[i], theme),
                        ),
            ),
            Divider(height: 1, color: theme.divider),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: isAuth && !_sending,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                        cursorColor: theme.btnPrimary,
                        decoration: InputDecoration(
                          hintText: isAuth
                              ? 'Tulis komentar...'
                              : 'Login untuk berkomentar',
                          hintStyle:
                              TextStyle(color: theme.textHint, fontSize: 13),
                          filled: true,
                          fillColor: theme.bgElevated,
                          isDense: true,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: (isAuth && !_sending) ? _send : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.btnPrimary,
                          foregroundColor: theme.btnLabel,
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const LucideIcon('send', size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentTile(PostComment c, ThemeProvider theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.bgElevated,
          backgroundImage: (c.authorAvatar?.isNotEmpty == true)
              ? NetworkImage(c.authorAvatar!)
              : null,
          child: (c.authorAvatar?.isNotEmpty == true)
              ? null
              : LucideIcon('user', color: theme.textHint, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeTime(c.createdAt),
                    style: TextStyle(color: theme.textHint, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                c.body,
                style: TextStyle(
                    color: theme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
    if (diff.inHours < 24) return '${diff.inHours} jam';
    if (diff.inDays < 7) return '${diff.inDays} hr';
    return '${t.day}/${t.month}/${t.year}';
  }
}
