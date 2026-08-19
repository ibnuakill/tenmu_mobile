import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Canvas-based marker image generator (PNG bytes for MapLibre addImage).
class MapMarkerPainter {
  /// Lingkaran dengan icon (Material) atau SVG asset.
  static Future<Uint8List> buildCircleMarkerImage({
    required Color bgColor,
    required int iconCode,
    String? svgAssetPath,
    int size = 100,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final center = Offset(size / 2.0, size / 2.0);
    final radius = size / 2.0 - 4.0;

    // Drop shadow
    canvas.drawCircle(
      Offset(center.dx, center.dy + 3),
      radius,
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Filled circle
    canvas.drawCircle(center, radius, Paint()..color = bgColor);

    // White border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );

    bool svgDrawn = false;
    if (svgAssetPath != null) {
      try {
        final svgString = await rootBundle.loadString(svgAssetPath);
        final pictureInfo = await vg.loadPicture(
          SvgStringLoader(svgString),
          null,
        );
        final svgPicture = pictureInfo.picture;
        final svgBounds = pictureInfo.size;
        final targetSize = size * 0.45;
        final scale = targetSize / math.max(svgBounds.width, svgBounds.height);
        canvas.save();
        canvas.translate(
          center.dx - (svgBounds.width * scale) / 2,
          center.dy - (svgBounds.height * scale) / 2,
        );
        canvas.scale(scale, scale);
        canvas.drawPicture(svgPicture);
        canvas.restore();
        svgDrawn = true;
      } catch (e) {
        debugPrint('[MAP] SVG render failed for $svgAssetPath: $e');
        svgDrawn = false;
      }
    }

    if (!svgDrawn) {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconCode),
          style: TextStyle(
            fontFamily: 'MaterialIcons',
            fontSize: size * 0.40,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Gmaps-style navigation arrow.
  static Future<Uint8List> buildNavArrowImage({
    required Color color,
    int size = 96,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final center = Offset(size / 2.0, size / 2.0);
    final radius = size / 2.0 - 8;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius) // Puncak
      ..lineTo(center.dx + radius * 0.7, center.dy + radius * 0.8) // Kanan
      ..lineTo(center.dx, center.dy + radius * 0.3) // Indent tengah bawah
      ..lineTo(center.dx - radius * 0.7, center.dy + radius * 0.8) // Kiri
      ..close();

    // Drop shadow
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // White stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 6.0,
    );

    // Fill
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
