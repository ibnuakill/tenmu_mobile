import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/poi_image_helper.dart';
import '../../../owner/edit_place_screen.dart';

// Quixotic Palette
const kPrimary      = Color(0xFF1E7A52);
const kAccentGreen  = Color(0xFF0FA968);
const kAccentAmber  = Color(0xFFF59E0B);
const kAccentRed    = Color(0xFFEF4444);
const kPageBg       = Color(0xFFF3F4F6);
const kCardBg       = Color(0xFFFFFFFF);
const kBorderColor  = Color(0xFFE5E7EB);
const kTextPrimary  = Color(0xFF111827);
const kTextSecondary= Color(0xFF6B7280);
const kTextMuted    = Color(0xFF9CA3AF);
const kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));



// ── Tab Pending ──────────────────────────────────────────────
class PendingTab extends StatelessWidget {
  final List<Map<String, dynamic>> placesList;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(Map<String, dynamic>) onApprove;
  final Function(Map<String, dynamic>, String) onReject;

  const PendingTab({
    super.key,
    required this.placesList,
    required this.isLoading,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kPrimary,
      backgroundColor: kCardBg,
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
          : placesList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kAccentGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: kAccentGreen),
                  ),
                  const SizedBox(height: 16),
                  Text('Tidak ada tempat menunggu verifikasi.',
                    style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: placesList.length,
              itemBuilder: (context, index) {
                final place = placesList[index];
                return PlaceCard(
                  place: place,
                  onApprove: () => onApprove(place),
                  onReject: () => _showRejectDialog(context, place),
                );
              },
            ),
    );
  }

  void _showRejectDialog(BuildContext context, Map<String, dynamic> place) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tolak Tempat',
          style: GoogleFonts.poppins(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alasan penolakan:',
              style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Jelaskan alasan penolakan...',
                hintStyle: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 13),
                fillColor: kPageBg,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorderColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              onReject(place, reasonController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text('Tolak', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Tab Verified ─────────────────────────────────────────────
class VerifiedTab extends StatefulWidget {
  final List<Map<String, dynamic>> placesList;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>) onToggleFeatured;

  const VerifiedTab({
    super.key,
    required this.placesList,
    required this.isLoading,
    required this.onRefresh,
    required this.onToggleFeatured,
  });

  @override
  State<VerifiedTab> createState() => VerifiedTabState();
}

class VerifiedTabState extends State<VerifiedTab> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: kPrimary,
      backgroundColor: kCardBg,
      child: widget.isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
          : widget.placesList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_outlined, size: 44, color: kPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text('Belum ada tempat yang diverifikasi.',
                    style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.placesList.length,
              itemBuilder: (context, index) {
                final place = widget.placesList[index];
                final imageUrl = PoiImageHelper.primaryImageUrl(place);
                final isFeatured = place['is_featured'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                    boxShadow: const [kShadow],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 54, height: 54,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 54, height: 54, color: kPageBg,
                                child: const Icon(Icons.image_not_supported_outlined, color: kTextMuted),
                              ),
                            )
                          : Container(
                              width: 54, height: 54, color: kPageBg,
                              child: const Icon(Icons.storefront_outlined, color: kPrimary),
                            ),
                    ),
                    title: Text(
                      place['nama_tempat'] ?? 'Tanpa Nama',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      place['alamat'] ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => widget.onToggleFeatured(place),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isFeatured ? kAccentAmber.withValues(alpha: 0.12) : kPageBg,
                              borderRadius: BorderRadius.circular(10),
                              border: isFeatured ? Border.all(color: kAccentAmber.withValues(alpha: 0.4)) : null,
                            ),
                            child: Icon(
                              isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFeatured ? kAccentAmber : kTextMuted,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditPlaceScreen(place: place)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kPageBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_outlined, color: kTextMuted, size: 18),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, color: kAccentGreen, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Tab Rejected ─────────────────────────────────────────────
class RejectedTab extends StatelessWidget {
  final List<Map<String, dynamic>> placesList;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const RejectedTab({
    super.key,
    required this.placesList,
    required this.isLoading,
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
          : placesList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kAccentRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_outlined, size: 44, color: kAccentRed),
                  ),
                  const SizedBox(height: 16),
                  Text('Belum ada tempat yang ditolak.',
                    style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: placesList.length,
              itemBuilder: (context, index) {
                final place = placesList[index];
                final imageUrl = PoiImageHelper.primaryImageUrl(place);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                    boxShadow: const [kShadow],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 54, height: 54,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 54, height: 54, color: kPageBg,
                                child: const Icon(Icons.image_not_supported_outlined, color: kTextMuted),
                              ),
                            )
                          : Container(
                              width: 54, height: 54, color: kPageBg,
                              child: const Icon(Icons.storefront_outlined, color: kTextMuted),
                            ),
                    ),
                    title: Text(
                      place['nama_tempat'] ?? 'Tanpa Nama',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place['alamat'] ?? '-',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12)),
                        if (place['rejection_reason'] != null)
                          Text('Alasan: ${place['rejection_reason']}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(color: kAccentRed, fontSize: 11)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditPlaceScreen(place: place)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kPageBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_outlined, color: kTextMuted, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.cancel_rounded, color: kAccentRed, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Place Card untuk Pending Tab ──────────────────────────────
class PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const PlaceCard({
    super.key,
    required this.place,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = PoiImageHelper.primaryImageUrl(place);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Column(
        children: [
          // ── Image ────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: double.infinity, height: 160, color: kPageBg,
                      child: const Icon(Icons.image_not_supported_outlined, color: kTextMuted, size: 40),
                    ),
                  )
                : Container(
                    width: double.infinity, height: 160, color: kPageBg,
                    child: const Icon(Icons.storefront_outlined, color: kPrimary, size: 40),
                  ),
          ),

          // ── Content ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['nama_tempat'] ?? 'Tanpa Nama',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  place['alamat'] ?? '-',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12),
                ),
                if (place['deskripsi'] != null && (place['deskripsi'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    place['deskripsi'],
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditPlaceScreen(place: place)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: Text('Edit', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextSecondary,
                          side: const BorderSide(color: kBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text('Tolak', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentRed.withValues(alpha: 0.1),
                          foregroundColor: kAccentRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(color: kAccentRed),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text('Setujui', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}