import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/lucide_icons.dart';

/// Bottom action bar: slide-to-start thumb untuk membuka rute (atau state "lokasi belum ada").
class DetailBottomActionBar extends StatefulWidget {
  final ThemeProvider theme;
  final double bottomPad;
  final bool hasLocation;
  final VoidCallback onRoute;

  const DetailBottomActionBar({
    super.key,
    required this.theme,
    required this.bottomPad,
    required this.hasLocation,
    required this.onRoute,
  });

  @override
  State<DetailBottomActionBar> createState() => _DetailBottomActionBarState();
}

class _DetailBottomActionBarState extends State<DetailBottomActionBar> {
  double _dragPosition = 0.0;
  bool _isActionTriggered = false;
  bool _isDragging = false;

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
              Expanded(
                child: widget.hasLocation
                    ? _SlideToStart(
                        theme: widget.theme,
                        dragPosition: _dragPosition,
                        isTriggered: _isActionTriggered,
                        isDragging: _isDragging,
                        onDragStart: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isDragging = true);
                        },
                        onDragUpdate: (dx) {
                          if (_isActionTriggered) return;
                          setState(() => _dragPosition += dx);
                        },
                        onDragEnd: (max) {
                          if (_isActionTriggered) return;
                          if (_dragPosition >= max * 0.8) {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _dragPosition = max;
                              _isActionTriggered = true;
                              _isDragging = false;
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
                            setState(() {
                              _dragPosition = 0.0;
                              _isDragging = false;
                            });
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
  final bool isDragging;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  const _SlideToStart({
    required this.theme,
    required this.dragPosition,
    required this.isTriggered,
    required this.isDragging,
    required this.onDragStart,
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
        final progress = max <= 0 ? 0.0 : (clamped / max).clamp(0.0, 1.0);
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
              // Efek 1: track terisi hijau seiring thumb digeser
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.btnPrimary.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ),
              ),
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
                      LucideIcon('chevrons-right',
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
                  onHorizontalDragStart: (_) => onDragStart(),
                  onHorizontalDragUpdate: (d) => onDragUpdate(d.delta.dx),
                  onHorizontalDragEnd: (_) => onDragEnd(max),
                  child: AnimatedScale(
                    scale: isDragging ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: theme.btnPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDragging
                                ? theme.btnPrimary.withValues(alpha: 0.55)
                                : Colors.black.withValues(alpha: 0.15),
                            blurRadius: isDragging ? 16 : 6,
                            spreadRadius: isDragging ? 1 : 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: LucideIcon('arrow-right',
                        color: theme.btnLabel,
                        size: 22,
                      ),
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
