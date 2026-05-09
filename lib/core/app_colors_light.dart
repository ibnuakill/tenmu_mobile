import 'package:flutter/material.dart';

/// Palet warna utama aplikasi TenMu (Light Mode)
///
/// Hirarki 5 level mengikuti standar Material Design light theme:
/// bgBase → bgSurface → bgElevated → border → borderFocus
abstract class AppColorsLight {
  // ── Background ─────────────────────────────────────────────────────────────
  /// Latar belakang halaman utama (putih bersih)
  static const Color bgBase = Color(0xFFFAFAFA);

  /// Latar belakang card / panel / sheet
  static const Color bgSurface = Color(0xFFFFFFFF);

  /// Latar belakang elemen elevated (input field, chip, dll.)
  static const Color bgElevated = Color(0xFFF5F5F5);

  // ── Border ─────────────────────────────────────────────────────────────────
  /// Border default (tidak aktif)
  static const Color border = Color(0xFFE0E0E0);

  /// Border saat elemen sedang fokus / aktif
  static const Color borderFocus = Color(0xFF9E9E9E);

  // ── Teks ───────────────────────────────────────────────────────────────────
  /// Teks utama (headings, label penting)
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Teks sekunder (sub-label, hint yang terlihat)
  static const Color textSecondary = Color(0xFF757575);

  /// Teks placeholder / hint yang redup
  static const Color textHint = Color(0xFFBDBDBD);

  // ── Ikon ───────────────────────────────────────────────────────────────────
  /// Warna ikon di dalam input field
  static const Color iconColor = Color(0xFF616161);

  // ── Tombol ─────────────────────────────────────────────────────────────────
  /// Warna latar tombol utama (gelap di atas background terang)
  static const Color btnPrimary = Color(0xFF1A1A1A);

  /// Warna label/teks di atas tombol utama
  static const Color btnLabel = Color(0xFFFAFAFA);

  // ── Feedback ───────────────────────────────────────────────────────────────
  /// Warna latar SnackBar error (merah terang)
  static const Color snackError = Color(0xFFFFEBEE);

  /// Warna latar SnackBar sukses (hijau terang)
  static const Color snackSuccess = Color(0xFFE8F5E9);

  /// Border SnackBar error
  static const Color snackErrorBorder = Color(0xFFEF5350);

  /// Border SnackBar sukses
  static const Color snackSuccessBorder = Color(0xFF66BB6A);

  // ── Divider ────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFEEEEEE);
}
