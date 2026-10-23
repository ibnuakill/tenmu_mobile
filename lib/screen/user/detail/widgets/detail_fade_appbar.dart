import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/lucide_icons.dart';

/// Floating appbar yang fade-in saat scroll.
/// Ditampilkan oleh parent hanya kalau opacity > 0.
class DetailFadeAppBar extends StatelessWidget {
  final ThemeProvider theme;
  final double opacity;
  final double topPadding;
  final String title;
  final bool isFavorite;
  final bool isLoadingFavorite;
  final VoidCallback onBack;
  final VoidCallback onTapFavorite;
  final bool hasPhone;
  final VoidCallback onWhatsApp;

  const DetailFadeAppBar({
    super.key,
    required this.theme,
    required this.opacity,
    required this.topPadding,
    required this.title,
    required this.isFavorite,
    required this.isLoadingFavorite,
    required this.onBack,
    required this.onTapFavorite,
    required this.hasPhone,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: Duration.zero,
      child: Container(
        height: topPadding + 56,
        color: theme.bgBase.withValues(alpha: opacity),
        child: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                icon: LucideIcon('chevron-left',
                  size: 18,
                  color: theme.textPrimary,
                ),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (hasPhone)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: GestureDetector(
                    onTap: onWhatsApp,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/brands/whatsapp.svg',
                          width: 17,
                          height: 17,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          semanticsLabel: 'WhatsApp',
                        ),
                      ),
                    ),
                  ),
                ),
              if (!isLoadingFavorite)
                IconButton(
                  icon: LucideIcon(
                    isFavorite
                        ? 'heart'
                        : 'heart',
                    color: isFavorite ? Colors.redAccent : theme.textPrimary,
                    size: 22,
                  ),
                  onPressed: onTapFavorite,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
