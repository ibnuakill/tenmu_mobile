import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';

/// Stats horizontal row (jarak / durasi / rating).
class DetailStatsRow extends StatelessWidget {
  final ThemeProvider theme;
  final String? durationText;
  final String? distanceText;
  final double avgRating;
  final int reviewCount;

  const DetailStatsRow({
    super.key,
    required this.theme,
    this.durationText,
    this.distanceText,
    this.avgRating = 0.0,
    this.reviewCount = 0,
  });

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ratingText = reviewCount > 0 ? avgRating.toStringAsFixed(1) : '--';
    final reviewLabel = reviewCount > 0
        ? '${_formatCount(reviewCount)} Ulasan'
        : 'Ulasan';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border.withValues(alpha: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.access_time_outlined,
                iconColor: theme.btnPrimary,
                value: durationText ?? '--',
                label: 'Durasi',
                theme: theme,
              ),
            ),
            VerticalDivider(
              color: theme.border.withValues(alpha: 0.5),
              thickness: 1,
              width: 1,
            ),
            Expanded(
              child: _StatItem(
                icon: Icons.location_on_outlined,
                iconColor: theme.btnPrimary,
                value: distanceText ?? '--',
                label: 'Jarak',
                theme: theme,
              ),
            ),
            VerticalDivider(
              color: theme.border.withValues(alpha: 0.5),
              thickness: 1,
              width: 1,
            ),
            Expanded(
              child: _StatItem(
                icon: Icons.star_outline_rounded,
                iconColor: Colors.amber,
                value: ratingText,
                label: reviewLabel,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final ThemeProvider theme;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.textHint,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Pill tab bar (Detail / Ulasan).
class DetailPillTabBar extends StatefulWidget {
  final TabController controller;
  final ThemeProvider theme;
  final List<String> tabs;

  const DetailPillTabBar({
    super.key,
    required this.controller,
    required this.theme,
    required this.tabs,
  });

  @override
  State<DetailPillTabBar> createState() => _DetailPillTabBarState();
}

class _DetailPillTabBarState extends State<DetailPillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.theme.bgSurface,
        borderRadius: BorderRadius.circular(32),
        border:
            Border.all(color: widget.theme.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: List.generate(widget.tabs.length, (i) {
          final active = widget.controller.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? widget.theme.btnPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  widget.tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? widget.theme.btnLabel
                        : widget.theme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
