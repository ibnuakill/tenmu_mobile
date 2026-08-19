import 'package:flutter/material.dart';
import '../../../../core/app_colors_light.dart';
import '../../../../core/theme_provider.dart';

/// Provider khusus admin — paksa light-mode agar sesuai desain Tenmu.
final adminThemeProvider = ThemeProvider(forceDarkMode: false);

// ── Tenmu Design System — Emerald Green Palette ──────────────────────────
// Referensi: Gambar UI Tenmu (Light Mode)
const kPrimary      = Color(0xFF1A1A1A);
const kAccentGreen  = Color(0xFF1ED760);
const kAccentAmber  = Color(0xFFF59E0B); // pending status
const kAccentRed    = Color(0xFFEF4444); // reject / error

// Layout backgrounds
const kPageBg       = AppColorsLight.bgBase;
const kSidebarBg    = AppColorsLight.bgSurface;
const kCardBg       = AppColorsLight.bgSurface;
const kBorderColor  = AppColorsLight.border;

// Typography palette
const kTextPrimary   = AppColorsLight.textPrimary;
const kTextSecondary = AppColorsLight.textSecondary;
const kTextMuted     = AppColorsLight.textHint;

// Shadow Tenmu (ultra soft)
const kShadow = BoxShadow(
  color: Color(0x0C000000),
  blurRadius: 16,
  offset: Offset(0, 4),
);