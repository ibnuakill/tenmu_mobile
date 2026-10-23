import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/lucide_icons.dart';
import '../core/notification_center.dart';
import '../core/theme_provider.dart';

/// Pop-up notifikasi gaya banner atas (muncul otomatis saat ada pesan baru).
///
/// - Auto-tutup setelah 7 detik.
/// - Ketuk kartu → jalankan [onTap] (biasanya buka layar notifikasi).
/// - Tidak memblokir layar (barrier transparan, bisa di-tap untuk menutup).
Future<void> showNotificationPopup(
  BuildContext context, {
  required AppNotification notification,
  VoidCallback? onTap,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup notifikasi',
    barrierColor: Colors.black.withValues(alpha: 0.06),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: _NotifPopupCard(
            notification: notification,
            onTap: onTap,
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

class _NotifPopupCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const _NotifPopupCard({required this.notification, this.onTap});

  @override
  State<_NotifPopupCard> createState() => _NotifPopupCardState();
}

class _NotifPopupCardState extends State<_NotifPopupCard> {
  Timer? _autoClose;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(seconds: 7), _dismiss);
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_closing || !mounted) return;
    _closing = true;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final n = widget.notification;
    final color = _typeColor(n.type);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          _autoClose?.cancel();
          _closing = true;
          Navigator.of(context).maybePop();
          widget.onTap?.call();
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: LucideIcon(_typeIcon(n.type), size: 20, color: color),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title.isEmpty ? 'Notifikasi' : n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'baru',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        n.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Ketuk untuk melihat',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: LucideIcon(
                              'x',
                              size: 14,
                              color: theme.textHint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'success':
    case 'approved':
      return const Color(0xFF16A34A);
    case 'warning':
    case 'rejected':
      return const Color(0xFFF59E0B);
    case 'promo':
      return const Color(0xFF7C3AED);
    case 'error':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF1A7A6E);
  }
}

String _typeIcon(String type) {
  switch (type) {
    case 'success':
    case 'approved':
      return 'circle-check';
    case 'warning':
    case 'rejected':
      return 'triangle-alert';
    case 'promo':
      return 'megaphone';
    case 'error':
      return 'circle-alert';
    default:
      return 'bell';
  }
}
