import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';

/// Bottom action bar: WhatsApp pill button + slide-to-start thumb (or "no location" state).
class DetailBottomActionBar extends StatefulWidget {
  final ThemeProvider theme;
  final double bottomPad;
  final bool hasPhone;
  final bool hasLocation;
  final VoidCallback onWhatsApp;
  final VoidCallback onRoute;

  const DetailBottomActionBar({
    super.key,
    required this.theme,
    required this.bottomPad,
    required this.hasPhone,
    required this.hasLocation,
    required this.onWhatsApp,
    required this.onRoute,
  });

  @override
  State<DetailBottomActionBar> createState() => _DetailBottomActionBarState();
}

class _DetailBottomActionBarState extends State<DetailBottomActionBar> {
  double _dragPosition = 0.0;
  bool _isActionTriggered = false;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + widget.bottomPad),
          decoration: BoxDecoration(
            color: widget.theme.bgBase.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(color: widget.theme.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (widget.hasPhone) ...[
                GestureDetector(
                  onTap: widget.onWhatsApp,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.theme.btnPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: widget.theme.btnLabel,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: widget.hasLocation
                    ? _SlideToStart(
                        theme: widget.theme,
                        dragPosition: _dragPosition,
                        isTriggered: _isActionTriggered,
                        onDragUpdate: (dx) {
                          if (_isActionTriggered) return;
                          setState(() => _dragPosition += dx);
                        },
                        onDragEnd: (max) {
                          if (_isActionTriggered) return;
                          if (_dragPosition >= max * 0.8) {
                            setState(() {
                              _dragPosition = max;
                              _isActionTriggered = true;
                            });
                            widget.onRoute();
                            Future.delayed(
                              const Duration(milliseconds: 600),
                              () {
                                if (mounted) {
                                  setState(() {
                                    _dragPosition = 0.0;
                                    _isActionTriggered = false;
                                  });
                                }
                              },
                            );
                          } else {
                            setState(() => _dragPosition = 0.0);
                          }
                        },
                      )
                    : Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: widget.theme.bgSurface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: widget.theme.border),
                        ),
                        child: Center(
                          child: Text(
                            'Lokasi tidak tersedia',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: widget.theme.textHint,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideToStart extends StatelessWidget {
  final ThemeProvider theme;
  final double dragPosition;
  final bool isTriggered;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  const _SlideToStart({
    required this.theme,
    required this.dragPosition,
    required this.isTriggered,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  static const double _thumbSize = 44.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth - _thumbSize - 8.0;
        final clamped = dragPosition.clamp(0.0, max);
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: theme.bgElevated,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: theme.border),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: (1.0 - (clamped / max)).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Geser Mulai Perjalanan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        size: 18,
                        color: theme.textHint,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 4.0 + clamped,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => onDragUpdate(d.delta.dx),
                  onHorizontalDragEnd: (_) => onDragEnd(max),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: theme.btnPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: theme.btnLabel,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
