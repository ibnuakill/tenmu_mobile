import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/user_role.dart';

// Quixotic palette
const kPrimary      = Color(0xFF1E7A52);
const kAccentGreen  = Color(0xFF0FA968);
const kAccentRed    = Color(0xFFEF4444);
const kPageBg       = Color(0xFFF3F4F6);
const kCardBg       = Color(0xFFFFFFFF);
const kBorderColor  = Color(0xFFE5E7EB);
const kTextPrimary  = Color(0xFF111827);
const kTextSecondary= Color(0xFF6B7280);
const kTextMuted    = Color(0xFF9CA3AF);
const kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));

class AllReviewsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final Future<void> Function() onRefresh;

  const AllReviewsTab({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = searchQuery.isEmpty
        ? reviews
        : reviews.where((r) {
            final komentar = (r['komentar'] ?? '').toLowerCase();
            final uid = (r['user_id'] ?? '').toLowerCase();
            return komentar.contains(searchQuery.toLowerCase()) ||
                uid.contains(searchQuery.toLowerCase());
          }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kPrimary,
      backgroundColor: kCardBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderColor),
                boxShadow: const [kShadow],
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: GoogleFonts.plusJakartaSans(color: kTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari komentar atau user ID...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} ulasan',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
                : filtered.isEmpty
                ? Center(
                    child: Text('Tidak ada ulasan.',
                      style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Container(height: 1, color: kBorderColor),
                    itemBuilder: (context, i) {
                      final review = filtered[i];
                      return AdminReviewTile(
                        review: review,
                        onDelete: () => onDelete(review),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class UserListTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final Future<void> Function(String userId) onDeleteAll;
  final Future<void> Function(String userId, UserRole role) onRoleChanged;
  final Future<void> Function(String userId, String name, bool isBanned) onToggleBan;
  final Future<void> Function() onRefresh;

  const UserListTab({
    super.key,
    required this.users,
    required this.reviews,
    required this.isLoading,
    required this.onDeleteAll,
    required this.onRoleChanged,
    required this.onToggleBan,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kPrimary,
      backgroundColor: kCardBg,
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
          : users.isEmpty
          ? Center(
              child: Text(
                'Belum ada data user di tabel profiles.',
                style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final user = users[i];
                final userId = user['id'] as String;
                final userReviews = reviews
                    .where((r) => r['user_id'] == userId)
                    .toList();

                final isBanned = user['status']?.toString() == 'banned';

                return UserTile(
                  userId: userId,
                  name:
                      user['nama']?.toString() ??
                      'Tanpa nama',
                  role: parseUserRole(user['role']),
                  reviewCount: userReviews.length,
                  reviews: userReviews,
                  isBanned: isBanned,
                  onDeleteAll: () => onDeleteAll(userId),
                  onRoleChanged: (role) => onRoleChanged(userId, role),
                  onToggleBan: () => onToggleBan(userId, user['nama']?.toString() ?? 'User', isBanned),
                );
              },
            ),
    );
  }
}

class AdminReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;

  const AdminReviewTile({super.key, required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int;
    final komentar = review['komentar'] as String?;
    final userId = review['user_id'] as String;
    final shortId = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;
    final createdAt = review['created_at'] != null
        ? DateTime.tryParse(review['created_at'])
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';
    final starColor = rating >= 4
        ? const Color(0xFFF59E0B)
        : rating >= 3 ? kTextSecondary : kAccentRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: starColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: starColor.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text('$rating★',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: starColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('User: $shortId',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: kTextMuted)),
                    const Spacer(),
                    Text(dateStr,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
                  ],
                ),
                if (komentar != null && komentar.isNotEmpty) ...
                  [
                    const SizedBox(height: 5),
                    Text(komentar,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: kTextSecondary, height: 1.4)),
                  ]
                else
                  Text('Tidak ada komentar.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: kTextMuted, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kAccentRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAccentRed.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.delete_outline_rounded, size: 16, color: kAccentRed),
            ),
          ),
        ],
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  final String userId;
  final String name;
  final UserRole role;
  final int reviewCount;
  final List<Map<String, dynamic>> reviews;
  final bool isBanned;
  final VoidCallback onDeleteAll;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback onToggleBan;

  const UserTile({
    super.key,
    required this.userId,
    required this.name,
    required this.role,
    required this.reviewCount,
    required this.reviews,
    required this.isBanned,
    required this.onDeleteAll,
    required this.onRoleChanged,
    required this.onToggleBan,
  });

  @override
  Widget build(BuildContext context) {
    final shortId = userId.length > 12 ? '${userId.substring(0, 12)}...' : userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBanned
            ? kAccentRed.withValues(alpha: 0.3) : kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          iconColor: kTextMuted,
          collapsedIconColor: kTextMuted,
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: isBanned
                ? kAccentRed.withValues(alpha: 0.10)
                : kPrimary.withValues(alpha: 0.10),
            child: Icon(
              isBanned ? Icons.block_rounded : Icons.person_rounded,
              size: 18,
              color: isBanned ? kAccentRed : kPrimary,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isBanned ? kTextMuted : kTextPrimary,
                    fontWeight: FontWeight.w700,
                    decoration: isBanned ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (isBanned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kAccentRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kAccentRed.withValues(alpha: 0.3)),
                  ),
                  child: Text('Banned',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: kAccentRed, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          subtitle: Text(
            '$reviewCount ulasan • $shortId',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPageBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role Akun',
                    style: GoogleFonts.plusJakartaSans(
                      color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    dropdownColor: kCardBg,
                    style: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kCardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimary, width: 1.5),
                      ),
                    ),
                    items: UserRole.values.map((item) =>
                      DropdownMenuItem<UserRole>(
                        value: item,
                        child: Text(item.label,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextPrimary)),
                      ),
                    ).toList(),
                    onChanged: (value) {
                      if (value != null && value != role) onRoleChanged(value);
                    },
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!isBanned)
                        Expanded(
                          child: GestureDetector(
                            onTap: onToggleBan,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: kAccentRed.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kAccentRed.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.block_rounded, size: 14, color: kAccentRed),
                                  const SizedBox(width: 6),
                                  Text('Nonaktifkan',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, color: kAccentRed, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (isBanned)
                        Expanded(
                          child: GestureDetector(
                            onTap: onToggleBan,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: kAccentGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kAccentGreen.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 14, color: kAccentGreen),
                                  const SizedBox(width: 6),
                                  Text('Aktifkan',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, color: kAccentGreen, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDeleteAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kAccentRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kAccentRed.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_sweep_rounded, size: 14, color: kAccentRed),
                          const SizedBox(width: 6),
                          Text('Hapus Semua Ulasan User Ini',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: kAccentRed, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...reviews.map(
              (r) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPageBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['rating']}★',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w700)),
                      if (r['komentar'] != null && r['komentar'] != '') ...
                        [
                          const SizedBox(height: 4),
                          Text(r['komentar'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: kTextSecondary)),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}