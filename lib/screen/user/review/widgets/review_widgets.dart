import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';

/// Deretan bintang (display only).
class ReviewStarRow extends StatelessWidget {
  final int rating;
  final double size;

  const ReviewStarRow({super.key, required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating ? const Color(0xFFFFB800) : theme.textHint,
        );
      }),
    );
  }
}

/// Ringkasan rata-rata bintang + jumlah ulasan.
class ReviewAverageBadge extends StatelessWidget {
  final double average;
  final int totalReviews;

  const ReviewAverageBadge({
    super.key,
    required this.average,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReviewStarRow(rating: average.round(), size: 20),
              const SizedBox(height: 4),
              Text(
                '$totalReviews ulasan',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu item review dengan menu edit/hapus (jika milik sendiri).
class ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReviewTile({
    super.key,
    required this.review,
    required this.isOwn,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
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
                  color: theme.bgElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.border),
                ),
                child: Center(
                  child: Text(
                    isOwn ? 'K' : 'U',
                    style: TextStyle(
                      color: theme.textSecondary,
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
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
                              color: theme.bgElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: theme.border),
                            ),
                            child: Text(
                              'Saya',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: theme.textHint),
                    ),
                  ],
                ),
              ),
              // Edit/hapus (jika milik sendiri)
              if (isOwn)
                PopupMenuButton<String>(
                  color: theme.bgElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.border),
                  ),
                  icon: Icon(Icons.more_vert, color: theme.iconColor, size: 18),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.iconColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(color: theme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Color(0xFF8B2020),
                          ),
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
          ReviewStarRow(rating: rating, size: 14),
          if (komentar != null && komentar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              komentar,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}