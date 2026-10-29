import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/admin_api.dart';
import '../dashboard/widgets/admin_design.dart';

/// Layar admin untuk meninjau dan memverifikasi pengajuan role Owner UMKM.
class ManageOwnerRequestsScreen extends StatefulWidget {
  const ManageOwnerRequestsScreen({super.key});

  @override
  State<ManageOwnerRequestsScreen> createState() =>
      _ManageOwnerRequestsScreenState();
}

class _ManageOwnerRequestsScreenState extends State<ManageOwnerRequestsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      // PII pengajuan ada di owner_requests (dilindungi RLS), profil hanya
      // dipakai untuk nama + avatar pendaftar.
      final data = await _client
          .from('owner_requests')
          .select(
            'user_id, nama_umkm, alamat, phone, note, status, requested_at, '
            'profiles!owner_requests_user_id_fkey(nama, avatar_url)',
          )
          .eq('status', 'pending')
          .order('requested_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Gagal memuat pengajuan: $e', isError: true);
    }
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    final userId = req['user_id'];
    final namaUmkm = req['nama_umkm'] ?? 'UMKM';

    try {
      await AdminApi.call('owner_approve', {'user_id': userId});

      _toast('Pengajuan "$namaUmkm" disetujui! User menjadi Pemilik UMKM.');
      _loadRequests();
    } on AdminApiException catch (e) {
      _toast('Gagal menyetujui: ${e.message}', isError: true);
    } catch (e) {
      _toast('Gagal menyetujui: $e', isError: true);
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final userId = req['user_id'];
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Tolak Pengajuan',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan alasan penolakan agar diketahui pendaftar:',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Alamat tidak valid',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kAccentRed),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminApi.call('owner_reject', {
          'user_id': userId,
          'reason': reasonController.text.trim(),
        });

        _toast('Pengajuan ditolak.');
        _loadRequests();
      } on AdminApiException catch (e) {
        _toast('Gagal menolak: ${e.message}', isError: true);
      } catch (e) {
        _toast('Gagal menolak: $e', isError: true);
      }
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontFamily: 'Nunito', color: Colors.white),
        ),
        backgroundColor: isError ? kAccentRed : kAccentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Pengajuan Owner UMKM',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kTextPrimary),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (ctx, i) => _buildCard(_requests[i]),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: kTextMuted),
          const SizedBox(height: 12),
          Text(
            'Tidak Ada Pengajuan Pending',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua pengajuan pendaftaran owner sudah diproses.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> req) {
    final profile = req['profiles'] as Map<String, dynamic>?;
    final nama = profile?['nama']?.toString() ?? 'User';
    final namaUmkm = req['nama_umkm'] ?? '-';
    final alamat = req['alamat'] ?? '-';
    final phone = req['phone'] ?? '-';
    final note = req['note'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kPrimary.withValues(alpha: 0.1),
                child: Text(
                  nama.isNotEmpty ? nama[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      'Pendaftar',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kAccentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kAccentAmber,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _rowInfo('Nama UMKM', namaUmkm),
          const SizedBox(height: 6),
          _rowInfo('Alamat', alamat),
          const SizedBox(height: 6),
          _rowInfo('Telepon/WA', phone),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            _rowInfo('Catatan', note),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentRed,
                    side: const BorderSide(color: kAccentRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approve(req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Setujui (Approve)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              color: kTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
