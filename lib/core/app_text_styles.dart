import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Kumpulan style teks yang dipakai di seluruh aplikasi TenMu.
/// Gunakan class ini agar typografi konsisten tanpa copy-paste.
abstract class AppTextStyles {
  // ── Display / Heading ──────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Body ───────────────────────────────────────────────────────────────────
  static const TextStyle bodyDefault = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  // ── Label ──────────────────────────────────────────────────────────────────
  /// Dipakai sebagai label di atas input field
  static const TextStyle fieldLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  // ── Button ─────────────────────────────────────────────────────────────────
  static const TextStyle btnLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.btnLabel,
    letterSpacing: 0.5,
  );

  // ── Link ───────────────────────────────────────────────────────────────────
  static const TextStyle linkPrimary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.textSecondary,
  );

  static const TextStyle linkSecondary = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
}
