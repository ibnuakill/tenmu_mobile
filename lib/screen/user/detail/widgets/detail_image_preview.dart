import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail_helpers.dart';

/// Full-screen image preview dialog with zoom + swipe + dot indicator.
class DetailImagePreview {
  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    required int initialIndex,
  }) {
    final previewController = PageController(initialPage: initialIndex);
    int previewIndex = initialIndex;

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                PageView.builder(
                  controller: previewController,
                  itemCount: imageUrls.length,
                  onPageChanged: (i) =>
                      setDialogState(() => previewIndex = i),
                  itemBuilder: (_, index) => InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrls[index],
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32,
                    child: ImageDotIndicator(
                      count: imageUrls.length,
                      currentIndex: previewIndex,
                    ),
                  ),
                Positioned(
                  top: 48,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
