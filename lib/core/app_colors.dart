import 'package:flutter/material.dart';

/// Palet warna utama aplikasi TenMu (Dark Mode)
///
/// Hirarki 5 level mengikuti standar Material Design dark theme:
/// bgBase → bgSurface → bgElevated → border → borderFocus
abstract class AppColors {
  // ── Background ─────────────────────────────────────────────────────────────
  /// Latar belakang halaman utama (deep pitch black)
  static const Color bgBase = Color(0xFF0C0C0C);

  /// Latar belakang card / panel / sheet (subtle dark surface)
  static const Color bgSurface = Color(0xFF141414);

  /// Latar belakang elemen elevated (input field, chip, dll.)
  static const Color bgElevated = Color(0xFF1C1C1C);

  // ── Border ─────────────────────────────────────────────────────────────────
  /// Border default (halus & menyatu dengan latar gelap)
  static const Color border = Color(0xFF262626);

  /// Border saat elemen sedang fokus / aktif
  static const Color borderFocus = Color(0xFF404040);

  // ── Teks ───────────────────────────────────────────────────────────────────
  /// Teks utama (headings, label penting)
  static const Color textPrimary = Color(0xFFEDEDED);

  /// Teks sekunder (sub-label, hint yang terlihat)
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// Teks placeholder / hint yang redup
  static const Color textHint = Color(0xFF6F6F6F);

  // ── Ikon ───────────────────────────────────────────────────────────────────
  /// Warna ikon di dalam input field
  static const Color iconColor = Color(0xFFB3B3B3);

  // ── Tombol ─────────────────────────────────────────────────────────────────
  /// Warna latar tombol utama (terang di atas background gelap)
  static const Color btnPrimary = Color(0xFF1ED760);

  /// Warna label/teks di atas tombol utama
  static const Color btnLabel = Color(0xFF121212);

  // ── Feedback ───────────────────────────────────────────────────────────────
  /// Warna latar SnackBar error (merah redup, tidak menyilaukan)
  static const Color snackError = Color(0xFF2A1A1A);

  /// Warna latar SnackBar sukses (hijau redup)
  static const Color snackSuccess = Color(0xFF13261A);

  /// Border SnackBar error
  static const Color snackErrorBorder = Color(0xFF8B0000);

  /// Border SnackBar sukses
  static const Color snackSuccessBorder = Color(0xFF1DB954);

  // ── Divider ────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFF2A2A2A);
}
