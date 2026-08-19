import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';

/// Tile khusus untuk switch dark / white mode.
class ThemeModeTile extends StatelessWidget {
  final ThemeProvider theme;
  const ThemeModeTile({super.key, required this.theme});

  static const Color _accent = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: _accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Tampilan',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Dark Mode aktif' : 'White Mode aktif',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _SegmentedToggle(
            isDark: isDark,
            theme: theme,
            onChanged: (v) => theme.setTheme(v),
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final bool isDark;
  final ThemeProvider theme;
  final ValueChanged<bool> onChanged;
  const _SegmentedToggle({
    required this.isDark,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            selected: isDark,
            theme: theme,
            onTap: () => onChanged(true),
          ),
          _SegmentButton(
            icon: Icons.light_mode_rounded,
            label: 'White',
            selected: !isDark,
            theme: theme,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ThemeProvider theme;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? theme.btnPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? theme.btnLabel : theme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? theme.btnLabel : theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
