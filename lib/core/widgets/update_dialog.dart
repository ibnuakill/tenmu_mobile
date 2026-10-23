import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_update_provider.dart';
import '../app_update_service.dart';
import '../lucide_icons.dart';
import '../theme_provider.dart';

/// Dialog pembaruan aplikasi. Menampilkan catatan rilis, progres unduhan,
/// dan tombol untuk mengunduh lalu memasang APK.
///
/// Mengembalikan `true` bila user memulai proses unduhan.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final update = context.watch<AppUpdateProvider>();
    final version = update.pendingVersion;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(theme),
            const SizedBox(height: 14),
            if (version != null) _changelog(theme, version),
            const SizedBox(height: 16),
            _statusArea(theme, update),
            const SizedBox(height: 20),
            _actions(context, theme, update),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.btnPrimary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: LucideIcon('download', size: 22, color: theme.btnPrimary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pembaruan Tersedia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Unduh versi terbaru TenMu',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _changelog(ThemeProvider theme, AppVersion version) {
    final notes = version.changelog.trim();
    if (notes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        notes,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  Widget _statusArea(ThemeProvider theme, AppUpdateProvider update) {
    switch (update.status) {
      case UpdateStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: update.progress,
                minHeight: 6,
                backgroundColor: theme.bgElevated,
                valueColor: AlwaysStoppedAnimation(theme.btnPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mengunduh... ${(update.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11.5, color: theme.textHint),
            ),
          ],
        );

      case UpdateStatus.ready:
        return Row(
          children: [
            LucideIcon('check', size: 16, color: theme.snackSuccess),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update siap dipasang. Tekan "Pasang Sekarang".',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
            ),
          ],
        );

      case UpdateStatus.failed:
        return Row(
          children: [
            LucideIcon('alert', size: 16, color: theme.snackError),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                update.errorMessage ?? 'Gagal mengunduh update.',
                style: TextStyle(fontSize: 12, color: theme.snackError),
              ),
            ),
          ],
        );

      case UpdateStatus.idle:
      case UpdateStatus.checking:
      case UpdateStatus.updateAvailable:
        return const SizedBox.shrink();
    }
  }

  Widget _actions(
    BuildContext context,
    ThemeProvider theme,
    AppUpdateProvider update,
  ) {
    final canSkip = !update.isMandatory && update.status != UpdateStatus.downloading;

    if (update.status == UpdateStatus.ready) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => context.read<AppUpdateProvider>().installUpdate(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.btnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Pasang Sekarang',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.btnLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (canSkip)
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () {
                  context.read<AppUpdateProvider>().dismiss();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Nanti',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        if (canSkip) const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: update.isBusy
                  ? null
                  : () => context.read<AppUpdateProvider>().downloadUpdate(),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                update.status == UpdateStatus.failed ? 'Coba Lagi' : 'Unduh',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: theme.btnLabel,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
