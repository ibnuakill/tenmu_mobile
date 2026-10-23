import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

/// Palet & komponen form tempat yang disamakan dengan halaman Login/Register.
///
/// Login/Register memakai `AuthPalette` (dark, AppColors) — class ini memakai
/// sumber warna yang sama supaya form tambah/edit tempat terlihat seragam:
/// background gelap, field abu gelap, tombol hijau, dan header tanpa AppBar
/// berjudul.
class PlaceFormStyle {
  const PlaceFormStyle();

  Color get bgBase => AppColors.bgBase;
  Color get bgSurface => AppColors.bgSurface;
  Color get bgElevated => AppColors.bgElevated;
  Color get border => AppColors.border;
  Color get borderFocus => AppColors.textPrimary;
  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textHint => AppColors.textHint;
  Color get iconColor => AppColors.textSecondary;
  Color get btnPrimary => AppColors.btnPrimary;
  Color get btnLabel => AppColors.btnLabel;
  Color get snackError => AppColors.snackError;
  Color get snackErrorBorder => AppColors.snackErrorBorder;
  Color get snackSuccess => AppColors.snackSuccess;
  Color get snackSuccessBorder => AppColors.snackSuccessBorder;

  static const Color _bg = AppColors.bgBase;

  /// AppBar transparan dengan tombol back bulat — sama seperti Login/Register.
  static PreferredSizeWidget appBar(BuildContext context) {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Judul besar + subjudul, persis pola header Login/Register.
class PlaceFormHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const PlaceFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Kartu pengelompokan field dengan judul kecil di atasnya.
class PlaceSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const PlaceSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Tombol utama hijau — sama dengan tombol "Masuk"/"Daftar" di halaman auth.
class PlacePrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  const PlacePrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.btnPrimary,
          disabledBackgroundColor: AppColors.btnPrimary.withValues(alpha: 0.35),
          foregroundColor: AppColors.btnLabel,
          disabledForegroundColor: AppColors.btnLabel.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.btnLabel,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: AppColors.btnLabel),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.btnLabel,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tombol sekunder bergaris (mis. "Peta Manual", "Upload Foto").
class PlaceSecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const PlaceSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
