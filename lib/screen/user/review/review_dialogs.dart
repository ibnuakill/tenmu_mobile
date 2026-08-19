import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';
import '../../auth/login_screen.dart';

/// Dialog "Login Diperlukan" untuk guest yang ingin memberi ulasan.
Future<void> showReviewLoginPrompt(BuildContext context) async {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: theme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Login Diperlukan',
        style: TextStyle(
          color: theme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Kamu perlu login terlebih dahulu untuk memberikan ulasan.',
        style: TextStyle(color: theme.textSecondary, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Nanti', style: TextStyle(color: theme.textSecondary)),
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
            backgroundColor: theme.btnPrimary,
            foregroundColor: theme.btnLabel,
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

/// Dialog konfirmasi hapus review. Kembalikan true jika dikonfirmasi.
Future<bool> showDeleteReviewConfirm(BuildContext context) async {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: theme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Hapus Ulasan?',
        style: TextStyle(
          color: theme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Ulasan kamu akan dihapus secara permanen.',
        style: TextStyle(color: theme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
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
  return confirmed ?? false;
}