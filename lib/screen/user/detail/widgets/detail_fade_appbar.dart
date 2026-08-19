import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';

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
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
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
              if (!isLoadingFavorite)
                IconButton(
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.redAccent : theme.textPrimary,
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
