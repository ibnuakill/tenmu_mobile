import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Quixotic palette (sama dengan admin_home_screen.dart)
const _kPrimary      = Color(0xFF1E7A52);
const _kAccentGreen  = Color(0xFF0FA968);
const _kAccentAmber  = Color(0xFFF59E0B);
const _kAccentRed    = Color(0xFFEF4444);
const _kPageBg       = Color(0xFFF3F4F6);
const _kCardBg       = Color(0xFFFFFFFF);
const _kBorderColor  = Color(0xFFE5E7EB);
const _kTextPrimary  = Color(0xFF111827);
const _kTextSecondary= Color(0xFF6B7280);
const _kTextMuted    = Color(0xFF9CA3AF);
const _kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('places')
          .select('id, nama_tempat, verification_status, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _activities = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorderColor),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: _kTextPrimary, size: 16),
          ),
        ),
        title: Text(
          'Aktivitas Terbaru',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorderColor),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, color: _kPrimary, size: 15),
                    const SizedBox(width: 5),
                    Text('Refresh',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5))
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _kBorderColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inbox_outlined, size: 44, color: _kTextMuted),
                      ),
                      const SizedBox(height: 16),
                      Text('Belum ada aktivitas',
                        style: GoogleFonts.poppins(
                          color: _kTextPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Aktivitas akan muncul di sini setelah ada data',
                        style: GoogleFonts.plusJakartaSans(color: _kTextMuted, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = _activities[i];
                    final name = a['nama_tempat'] ?? 'Unknown';
                    final status = a['verification_status'] ?? 'pending';
                    final createdAt = a['created_at'] as String? ?? '';
                    final timeAgo = _timeAgo(createdAt);
                    return _activityItem(name, status, timeAgo);
                  },
                ),
    );
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${diff.inDays ~/ 7} minggu lalu';
  }

  Widget _activityItem(String name, String status, String time) {
    IconData icon;
    Color color;
    String desc;
    String badge;

    switch (status) {
      case 'verified':
        icon = Icons.check_circle_rounded;
        color = _kAccentGreen;
        desc = 'diverifikasi';
        badge = 'Berhasil';
        break;
      case 'rejected':
        icon = Icons.cancel_rounded;
        color = _kAccentRed;
        desc = 'ditolak';
        badge = 'Ditolak';
        break;
      default:
        icon = Icons.schedule_rounded;
        color = _kAccentAmber;
        desc = 'menunggu review';
        badge = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [_kShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: _kTextSecondary, height: 1.4),
                    children: [
                      TextSpan(
                        text: name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, color: _kTextPrimary, fontSize: 13),
                      ),
                      TextSpan(text: ' $desc'),
                    ],
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(time,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(badge,
              style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
