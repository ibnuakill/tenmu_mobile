import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/lucide_icons.dart';

/// Tombol ganti mode tampilan — ikon saja, tanpa teks.
///
/// Warna tombol mengikuti mode yang sedang aktif:
/// - Dark mode  → lingkaran gelap, ikon bulan putih
/// - White mode → lingkaran terang, ikon matahari kuning
///
/// Ketuk untuk berpindah mode. Pilihan disimpan otomatis oleh [ThemeProvider].
class ThemeModeTile extends StatelessWidget {
  final ThemeProvider theme;
  const ThemeModeTile({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDarkMode;

    // Warna mengikuti mode aktif: gelap saat dark, terang saat white.
    final Color bg = isDark ? const Color(0xFF141417) : const Color(0xFFFFFFFF);
    final Color fg = isDark ? const Color(0xFFF2F2F7) : const Color(0xFFF5A524);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFDFDFE6);

    return Tooltip(
      message: isDark ? 'Ganti ke mode terang' : 'Ganti ke mode gelap',
      child: Semantics(
        button: true,
        label: isDark ? 'Mode gelap aktif' : 'Mode terang aktif',
        child: GestureDetector(
          onTap: () => theme.setTheme(!isDark),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: LucideIcon(
                  isDark ? 'moon' : 'sun',
                  key: ValueKey<bool>(isDark),
                  size: 20,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
