import 'package:flutter/material.dart';

/// Palet warna utama aplikasi TenMu (Dark Mode)
///
/// Hirarki 5 level mengikuti standar Material Design dark theme:
/// bgBase → bgSurface → bgElevated → border → borderFocus
abstract class AppColors {
  // ── Background ─────────────────────────────────────────────────────────────
  /// Latar belakang halaman utama (hitam dalam)
  static const Color bgBase = Color(0xFF0A0A0A);

  /// Latar belakang card / panel / sheet
  static const Color bgSurface = Color(0xFF141414);

  /// Latar belakang elemen elevated (input field, chip, dll.)
  static const Color bgElevated = Color(0xFF1E1E1E);

  // ── Border ─────────────────────────────────────────────────────────────────
  /// Border default (tidak aktif)
  static const Color border = Color(0xFF2C2C2C);

  /// Border saat elemen sedang fokus / aktif
  static const Color borderFocus = Color(0xFF6B6B6B);

  // ── Teks ───────────────────────────────────────────────────────────────────
  /// Teks utama (headings, label penting)
  static const Color textPrimary = Color(0xFFEDEDED);

  /// Teks sekunder (sub-label, hint yang terlihat)
  static const Color textSecondary = Color(0xFF8A8A8A);

  /// Teks placeholder / hint yang redup
  static const Color textHint = Color(0xFF4A4A4A);

  // ── Ikon ───────────────────────────────────────────────────────────────────
  /// Warna ikon di dalam input field
  static const Color iconColor = Color(0xFF9E9E9E);

  // ── Tombol ─────────────────────────────────────────────────────────────────
  /// Warna latar tombol utama (terang di atas background gelap)
  static const Color btnPrimary = Color(0xFFEDEDED);

  /// Warna label/teks di atas tombol utama
  static const Color btnLabel = Color(0xFF0A0A0A);

  // ── Feedback ───────────────────────────────────────────────────────────────
  /// Warna latar SnackBar error (merah redup, tidak menyilaukan)
  static const Color snackError = Color(0xFF2A1A1A);

  /// Warna latar SnackBar sukses (hijau redup)
  static const Color snackSuccess = Color(0xFF1A2A1A);

  /// Border SnackBar error
  static const Color snackErrorBorder = Color(0xFF8B0000);

  /// Border SnackBar sukses
  static const Color snackSuccessBorder = Color(0xFF1A5C1A);

  // ── Divider ────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFF222222);
}
