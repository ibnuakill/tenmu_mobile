import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme_provider.dart';
import 'review_dialogs.dart';
import 'widgets/review_input_sheet.dart';
import 'widgets/review_widgets.dart';

/// Section ulasan POI: ringkasan rating + list review + input/edit/hapus.
class ReviewSection extends StatefulWidget {
  final int umkmId;

  const ReviewSection({super.key, required this.umkmId});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  Map<String, dynamic>? _myReview;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('reviews')
          .select()
          .eq('umkm_id', widget.umkmId)
          .order('created_at', ascending: false);

      final userId = _client.auth.currentUser?.id;
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data);
        _myReview = userId != null
            ? _reviews.where((r) => r['user_id'] == userId).firstOrNull
            : null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(0, (sum, r) => sum + (r['rating'] as int));
    return total / _reviews.length;
  }

  void _openReviewSheet() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isEdit = _myReview != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReviewInputSheet(
        umkmId: widget.umkmId,
        existingReview: _myReview,
        isEdit: isEdit,
        onSubmitted: _loadReviews,
      ),
    );
  }

  Future<void> _deleteMyReview() async {
    if (_myReview == null) return;
    final confirmed = await showDeleteReviewConfirm(context);
    if (confirmed && mounted) {
      await _client.from('reviews').delete().eq('id', _myReview!['id']);
      await _loadReviews();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final userId = _client.auth.currentUser?.id;
    final isLoggedIn = userId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.border),
        const SizedBox(height: 20),

        // Header
        Row(
          children: [
            Text(
              'Ulasan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: isLoggedIn
                  ? _openReviewSheet
                  : () => showReviewLoginPrompt(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.bgElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLoggedIn
                          ? (_myReview != null
                                ? Icons.edit_outlined
                                : Icons.rate_review_outlined)
                          : Icons.lock_outline,
                      size: 14,
                      color: theme.iconColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLoggedIn
                          ? (_myReview != null ? 'Edit Ulasan' : 'Beri Ulasan')
                          : 'Login untuk beri ulasan',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Rating summary
        if (!_isLoading && _reviews.isNotEmpty) ...[
          ReviewAverageBadge(
            average: _averageRating,
            totalReviews: _reviews.length,
          ),
          const SizedBox(height: 20),
        ],

        // Content
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: theme.iconColor),
            ),
          )
        else if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: theme.textHint,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Belum ada ulasan. Jadilah yang pertama!',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _reviews.length,
            separatorBuilder: (_, _) => Divider(color: theme.border, height: 1),
            itemBuilder: (context, index) {
              final review = _reviews[index];
              final isOwn = review['user_id'] == userId;
              return ReviewTile(
                review: review,
                isOwn: isOwn,
                onEdit: isOwn ? _openReviewSheet : null,
                onDelete: isOwn ? _deleteMyReview : null,
              );
            },
          ),
      ],
    );
  }
}