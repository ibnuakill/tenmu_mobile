import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/account_service.dart';
import '../../../../core/theme_provider.dart';

/// Bagian "Zona Berbahaya" di Pengaturan Profil.
///
/// Wajib ada menurut kebijakan Google Play: aplikasi yang punya pendaftaran
/// akun harus menyediakan cara menghapus akun dari dalam aplikasi.
class DeleteAccountSection extends StatefulWidget {
  const DeleteAccountSection({super.key});

  @override
  State<DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends State<DeleteAccountSection> {
  bool _busy = false;

  Future<void> _confirmAndDelete() async {
    final ThemeProvider theme = context.read<ThemeProvider>();
    final bool? agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _DeleteConfirmDialog(theme: theme),
    );
    if (agreed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountService.deleteMyAccount();

      // Akun sudah hilang di server — bersihkan sesi lokal.
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      // AuthGate mendengarkan perubahan sesi, jadi cukup kembali ke root.
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun kamu sudah dihapus. Terima kasih sudah memakai TenMu.'),
        ),
      );
    } on AccountServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeProvider theme = context.watch<ThemeProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Zona Berbahaya',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Menghapus akun bersifat permanen. Ulasan, favorit, dan data '
            'pengajuan kamu akan ikut terhapus dan tidak bisa dikembalikan.',
            style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _busy ? null : _confirmAndDelete,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  : Text(
                      'Hapus Akun Saya',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog konfirmasi: user wajib mengetik "HAPUS" supaya tidak terklik
/// tanpa sengaja.
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.theme});

  final ThemeProvider theme;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeProvider theme = widget.theme;

    return AlertDialog(
      backgroundColor: theme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Hapus akun permanen?',
        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tindakan ini tidak bisa dibatalkan. Ketik HAPUS untuk melanjutkan.',
            style: TextStyle(color: theme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: theme.textPrimary),
            onChanged: (String v) {
              final bool ok = v.trim().toUpperCase() == 'HAPUS';
              if (ok != _canDelete) setState(() => _canDelete = ok);
            },
            decoration: InputDecoration(
              hintText: 'HAPUS',
              hintStyle: TextStyle(color: theme.textHint),
              filled: true,
              fillColor: theme.bgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            'Hapus Akun',
            style: TextStyle(
              color: _canDelete ? Colors.red.shade400 : theme.textHint,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
