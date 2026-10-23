import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon Lucide berbasis SVG (set default "Semantic UI", garis tipis & clean).
///
/// Dipakai untuk seluruh layar USER supaya gaya icon seragam. Warnanya
/// mengikuti [color] (atau IconTheme di sekitarnya), jadi bisa di-tint bebas.
///
/// Contoh:
/// ```dart
/// LucideIcon('house', size: 22, color: Colors.white)
/// LucideIcon('star')            // ukuran & warna ikut IconTheme
/// ```
class LucideIcon extends StatelessWidget {
  /// Nama file di `assets/icons/lucide/<name>.svg` (tanpa `.svg`).
  final String name;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const LucideIcon(
    this.name, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// Path asset untuk [name].
  static String assetPath(String name) => 'assets/icons/lucide/$name.svg';

  /// Semua nama Lucide yang tersedia di bundle (untuk validasi/otocomplete).
  static const Set<String> available = {
    'store', 'star', 'image-off', 'image', 'x', 'user', 'heart', 'badge-check',
    'refresh-cw', 'message-square', 'map-pin', 'arrow-left', 'chevron-left',
    'send', 'search', 'bell', 'navigation', 'sun', 'compass', 'pencil', 'moon',
    'chevron-right', 'message-circle', 'sparkles', 'arrow-right', 'wifi-off',
    'triangle-alert', 'bike', 'sliders-horizontal', 'pointer', 'timer', 'ruler',
    'clock', 'utensils', 'message-square-text', 'images', 'phone', 'palette',
    'notebook-text', 'locate-fixed', 'ellipsis-vertical', 'map', 'log-out',
    'lock', 'map-pin-off', 'tag', 'mountain', 'chevrons-right', 'chevron-down',
    'info', 'hourglass', 'hotel', 'house', 'flag', 'mail', 'map-pin-pen',
    'check-check', 'footprints', 'car', 'route', 'trash', 'circle-check',
    'circle-x', 'megaphone', 'camera', 'wrench', 'bookmark', 'image-plus',
    'message-square-plus', 'circle-plus', 'chevron-up', 'circle-alert',
    'square-pen', 'list-filter', 'settings', 'log-in', 'rotate-ccw-clock',
    'landmark', 'gift', 'shopping-cart', 'download', 'check', 'alert',
  };

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor = color ?? iconTheme.color ?? Colors.white;

    // PENTING: dibungkus Center(widthFactor/heightFactor = 1) supaya SVG TIDAK
    // melar mengisi parent berukuran tetap (mis. Container 44x44). Tanpa ini,
    // ikon Lucide tampak sebesar container-nya ("gede banget") — beda dengan
    // Icon Material yang ukurannya berasal dari fontSize, bukan dari box.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        assetPath(name),
        width: resolvedSize,
        height: resolvedSize,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        semanticsLabel: semanticLabel ?? name,
      ),
    );
  }
}
