import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme_provider.dart';
import '../../../core/lucide_icons.dart';

/// Layar pengajuan menjadi Pemilik UMKM.
/// User mengisi data singkat, lalu pengajuan masuk ke admin untuk disetujui.
class OwnerRequestScreen extends StatefulWidget {
  const OwnerRequestScreen({super.key});

  @override
  State<OwnerRequestScreen> createState() => _OwnerRequestScreenState();
}

class _OwnerRequestScreenState extends State<OwnerRequestScreen> {
  final _namaUmkmController = TextEditingController();
  final _alamatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _status = 'none'; // none | pending | approved | rejected
  String? _rejectionReason;
  DateTime? _requestedAt;

  @override
  void initState() {
    super.initState();
    _loadRequestStatus();
  }

  @override
  void dispose() {
    _namaUmkmController.dispose();
    _alamatController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadRequestStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select(
            'role, owner_request_status, owner_request_nama_umkm, '
            'owner_request_alamat, owner_request_phone, owner_request_note, '
            'owner_requested_at, owner_request_rejection',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        // Kalau sudah owner, anggap approved
        final role = data['role']?.toString();
        final status = role == 'owner'
            ? 'approved'
            : (data['owner_request_status']?.toString() ?? 'none');

        setState(() {
          _status = status;
          _rejectionReason = data['owner_request_rejection']?.toString();
          _requestedAt = DateTime.tryParse(
            data['owner_requested_at']?.toString() ?? '',
          );
          _namaUmkmController.text =
              data['owner_request_nama_umkm']?.toString() ?? '';
          _alamatController.text = data['owner_request_alamat']?.toString() ?? '';
          _phoneController.text = data['owner_request_phone']?.toString() ?? '';
          _noteController.text = data['owner_request_note']?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Gagal memuat status pengajuan.', isError: true);
    }
  }

  Future<void> _submit() async {
    final namaUmkm = _namaUmkmController.text.trim();
    final alamat = _alamatController.text.trim();
    final phone = _phoneController.text.trim();

    if (namaUmkm.isEmpty) {
      _toast('Nama UMKM wajib diisi.', isError: true);
      return;
    }
    if (alamat.isEmpty) {
      _toast('Alamat wajib diisi.', isError: true);
      return;
    }
    if (phone.isEmpty) {
      _toast('Nomor telepon wajib diisi.', isError: true);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('profiles').update({
        'owner_request_status': 'pending',
        'owner_request_nama_umkm': namaUmkm,
        'owner_request_alamat': alamat,
        'owner_request_phone': phone,
        'owner_request_note': _noteController.text.trim(),
        'owner_requested_at': DateTime.now().toIso8601String(),
        'owner_request_rejection': null,
      }).eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _status = 'pending';
        _requestedAt = DateTime.now();
        _isSubmitting = false;
      });
      _toast('Pengajuan terkirim! Menunggu persetujuan admin.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _toast('Gagal mengirim pengajuan: $e', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? theme.snackErrorBorder : theme.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Text(
          'Jadi Pemilik UMKM',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildBody(theme),
            ),
    );
  }

  Widget _buildBody(ThemeProvider theme) {
    switch (_status) {
      case 'approved':
        return _statusCard(
          theme: theme,
          icon: 'badge-check',
          color: const Color(0xFF22C55E),
          title: 'Kamu Sudah Jadi Pemilik UMKM 🎉',
          message:
              'Akunmu sudah berstatus Pemilik UMKM. Sekarang kamu bisa menambah dan mengelola tempat UMKM dari menu Pengaturan → Tambah Tempat.',
        );
      case 'pending':
        return _statusCard(
          theme: theme,
          icon: 'hourglass',
          color: const Color(0xFFF59E0B),
          title: 'Pengajuan Sedang Ditinjau',
          message:
              'Pengajuanmu sudah terkirim dan sedang menunggu persetujuan admin. '
              'Kamu akan bisa menambah tempat setelah disetujui.\n\n'
              'Dikirim: ${_formatDate(_requestedAt)}',
        );
      case 'rejected':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(
              theme: theme,
              icon: 'circle-x',
              color: const Color(0xFFEF4444),
              title: 'Pengajuan Ditolak',
              message:
                  'Pengajuanmu belum disetujui.'
                  '${_rejectionReason != null && _rejectionReason!.isNotEmpty ? '\n\nAlasan: $_rejectionReason' : ''}\n\n'
                  'Kamu bisa memperbaiki data lalu mengajukan ulang.',
            ),
            const SizedBox(height: 24),
            _buildForm(theme),
          ],
        );
      default:
        return _buildForm(theme);
    }
  }

  Widget _buildForm(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: Row(
            children: [
              LucideIcon('store', color: theme.iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Daftarkan usahamu agar bisa menambahkan tempat (UMKM) ke TenMu. '
                  'Isi data di bawah, lalu tunggu persetujuan admin.',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label(theme, 'Nama UMKM'),
        const SizedBox(height: 8),
        _field(
          theme,
          controller: _namaUmkmController,
          hint: 'Contoh: Kopi Senja',
          icon: 'store',
        ),
        const SizedBox(height: 18),
        _label(theme, 'Alamat UMKM'),
        const SizedBox(height: 8),
        _field(
          theme,
          controller: _alamatController,
          hint: 'Jl. Contoh No. 10, Kota',
          icon: 'map-pin',
          maxLines: 2,
        ),
        const SizedBox(height: 18),
        _label(theme, 'Nomor Telepon / WhatsApp'),
        const SizedBox(height: 8),
        _field(
          theme,
          controller: _phoneController,
          hint: '08xxxxxxxxxx',
          icon: 'phone',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 18),
        _label(theme, 'Catatan (opsional)'),
        const SizedBox(height: 8),
        _field(
          theme,
          controller: _noteController,
          hint: 'Info tambahan tentang usahamu',
          icon: 'notebook-text',
          maxLines: 3,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.btnPrimary,
              foregroundColor: theme.btnLabel,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Text(
                    'Kirim Pengajuan',
                    style: TextStyle(
                      color: theme.btnLabel,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required ThemeProvider theme,
    required String icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: LucideIcon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(ThemeProvider theme, String text) => Text(
        text,
        style: TextStyle(
          color: theme.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      );

  Widget _field(
    ThemeProvider theme, {
    required TextEditingController controller,
    required String hint,
    required String icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontSize: 15),
      cursorColor: theme.borderFocus,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textHint, fontSize: 14),
        prefixIcon: LucideIcon(icon, color: theme.iconColor, size: 20),
        filled: true,
        fillColor: theme.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.borderFocus, width: 1.5),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
