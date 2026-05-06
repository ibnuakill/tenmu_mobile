import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';

/// Widget lengkap Rating & Komentar untuk halaman detail UMKM.
///
/// Cara pakai:
/// ```dart
/// ReviewSection(umkmId: umkm['id'])
/// ```
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

  // Review milik user yang sedang login (null jika belum review)
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

  // ── Rata-rata bintang ──────────────────────────────────────
  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(
      0,
      (sum, r) => sum + (r['rating'] as int),
    );
    return total / _reviews.length;
  }

  // ── Buka dialog prompt login untuk guest ───────────────────
  void _promptLogin(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Login Diperlukan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Kamu perlu login terlebih dahulu untuk memberikan ulasan.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Nanti',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.btnPrimary,
              foregroundColor: AppColors.btnLabel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Login Sekarang'),
          ),
        ],
      ),
    );
  }

  // ── Buka bottom sheet untuk tulis/edit review ─────────────
  void _openReviewSheet() {
    final isEdit = _myReview != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReviewInputSheet(
        umkmId: widget.umkmId,
        existingReview: _myReview,
        isEdit: isEdit,
        onSubmitted: _loadReviews,
      ),
    );
  }

  // ── Hapus review milik sendiri ─────────────────────────────
  Future<void> _deleteMyReview() async {
    if (_myReview == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Ulasan?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Ulasan kamu akan dihapus secara permanen.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _client
          .from('reviews')
          .delete()
          .eq('id', _myReview!['id']);
      await _loadReviews();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _client.auth.currentUser?.id;
    final isLoggedIn = userId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.border),
        const SizedBox(height: 20),

        // ── Header: judul + tombol beri ulasan ──────────────
        Row(
          children: [
            const Text(
              'Ulasan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            // Tombol beri ulasan — adapts berdasarkan login status
            GestureDetector(
              onTap: isLoggedIn ? _openReviewSheet : () => _promptLogin(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
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
                      color: AppColors.iconColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLoggedIn
                          ? (_myReview != null ? 'Edit Ulasan' : 'Beri Ulasan')
                          : 'Login untuk beri ulasan',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

        // ── Ringkasan rata-rata bintang ──────────────────────
        if (!_isLoading && _reviews.isNotEmpty) ...[
          _AverageBadge(
            average: _averageRating,
            totalReviews: _reviews.length,
          ),
          const SizedBox(height: 20),
        ],

        // ── Konten ──────────────────────────────────────────
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppColors.iconColor),
            ),
          )
        else if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada ulasan. Jadilah yang pertama!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
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
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final review = _reviews[index];
              final isOwn = review['user_id'] == userId;
              return _ReviewTile(
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

// ── Widget: Ringkasan rata-rata bintang ─────────────────────────────────────
class _AverageBadge extends StatelessWidget {
  final double average;
  final int totalReviews;

  const _AverageBadge({required this.average, required this.totalReviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StarRow(rating: average.round(), size: 20),
              const SizedBox(height: 4),
              Text(
                '$totalReviews ulasan',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget: Satu item review ────────────────────────────────────────────────
class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ReviewTile({
    required this.review,
    required this.isOwn,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int;
    final komentar = review['komentar'] as String?;
    final createdAt = review['created_at'] != null
        ? DateTime.tryParse(review['created_at'])
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    isOwn ? 'K' : 'U',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOwn ? 'Kamu' : 'Pengguna',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Saya',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu edit/hapus jika milik sendiri
              if (isOwn)
                PopupMenuButton<String>(
                  color: AppColors.bgElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.iconColor,
                    size: 18,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.iconColor),
                          SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Color(0xFF8B2020)),
                          SizedBox(width: 8),
                          Text(
                            'Hapus',
                            style: TextStyle(color: Color(0xFF8B2020)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          _StarRow(rating: rating, size: 14),
          if (komentar != null && komentar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              komentar,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widget: Deretan bintang ─────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating ? const Color(0xFFFFB800) : AppColors.textHint,
        );
      }),
    );
  }
}

// ── Bottom Sheet: Input review baru / edit review ───────────────────────────
class _ReviewInputSheet extends StatefulWidget {
  final int umkmId;
  final Map<String, dynamic>? existingReview;
  final bool isEdit;
  final VoidCallback onSubmitted;

  const _ReviewInputSheet({
    required this.umkmId,
    required this.existingReview,
    required this.isEdit,
    required this.onSubmitted,
  });

  @override
  State<_ReviewInputSheet> createState() => _ReviewInputSheetState();
}

class _ReviewInputSheetState extends State<_ReviewInputSheet> {
  final _client = Supabase.instance.client;
  final _controller = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.existingReview != null) {
      _selectedRating = widget.existingReview!['rating'] as int;
      _controller.text = widget.existingReview!['komentar'] ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih bintang terlebih dahulu.'),
          backgroundColor: AppColors.snackError,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final userId = _client.auth.currentUser!.id;

    try {
      if (widget.isEdit && widget.existingReview != null) {
        // UPDATE
        await _client.from('reviews').update({
          'rating': _selectedRating,
          'komentar': _controller.text.trim().isEmpty
              ? null
              : _controller.text.trim(),
        }).eq('id', widget.existingReview!['id']);
      } else {
        // INSERT (UPSERT agar tidak duplikat)
        await _client.from('reviews').upsert({
          'umkm_id': widget.umkmId,
          'user_id': userId,
          'rating': _selectedRating,
          'komentar': _controller.text.trim().isEmpty
              ? null
              : _controller.text.trim(),
        }, onConflict: 'umkm_id, user_id');
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'Ulasan berhasil diperbarui.'
                  : 'Ulasan berhasil dikirim.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.snackSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.snackSuccessBorder),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim ulasan: $e',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.snackError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.snackErrorBorder),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            widget.isEdit ? 'Edit Ulasan' : 'Beri Ulasan',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bagaimana pengalamanmu di tempat ini?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 20),

          // ── Pilih bintang ─────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final starValue = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starValue <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: starValue <= _selectedRating
                          ? const Color(0xFFFFB800)
                          : AppColors.textHint,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 6),
          Center(
            child: Text(
              _selectedRating == 0
                  ? 'Ketuk bintang untuk memberi nilai'
                  : _ratingLabel(_selectedRating),
              style: TextStyle(
                fontSize: 13,
                color: _selectedRating > 0
                    ? const Color(0xFFFFB800)
                    : AppColors.textHint,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Input komentar ────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              cursorColor: AppColors.borderFocus,
              decoration: const InputDecoration(
                hintText:
                    'Tulis komentarmu (opsional)...',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                counterStyle: TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Tombol kirim ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.btnLabel,
                      ),
                    )
                  : Text(
                      widget.isEdit ? 'Perbarui Ulasan' : 'Kirim Ulasan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.btnLabel,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Buruk';
      case 2:
        return 'Kurang Baik';
      case 3:
        return 'Cukup';
      case 4:
        return 'Bagus';
      case 5:
        return 'Luar Biasa!';
      default:
        return '';
    }
  }
}
