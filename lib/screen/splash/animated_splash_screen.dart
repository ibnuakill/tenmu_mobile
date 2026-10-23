import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Splash dengan animasi Lottie globe/peta berputar (map-themed).
/// Aset: `assets/lottie/splash_map.json` (dari LottieFiles, spinning globe).
/// Kalau aset gagal dimuat, otomatis fallback ke ikon aplikasi statis.
class AnimatedSplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const AnimatedSplashScreen({super.key, required this.nextScreen});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  static const String _lottieAsset = 'assets/lottie/splash_global_network.json';

  /// Durasi animasi Lottie (153 frame @ 22fps ≈ 7s) — dipendek supaya ringan.
  static const Duration _animDuration = Duration(milliseconds: 4500);
  static const Duration _holdBeforeNext = Duration(milliseconds: 4700);

  late final AnimationController _controller;

  /// Globe putar selama 4s, judul & tagline fade-in setelah animasi mulai.
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  /// Globe fade-in dari bawah saat splash buka.
  late final Animation<double> _lottieOpacity;
  late final Animation<double> _lottieSlide;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animDuration,
    );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.36, 0.58, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.74, curve: Curves.easeOut),
    );
    _lottieOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _lottieSlide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _navigationTimer = Timer(_holdBeforeNext, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Globe berputar dengan fade-in dari bawah saat splash buka.
  Widget _buildAnimation() {
    const boxSize = 300.0;
    return FadeTransition(
      opacity: _lottieOpacity,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(_lottieSlide),
        child: SizedBox(
          width: boxSize,
          height: boxSize,
          // RepaintBoundary: animasi Lottie direpaint terpisah supaya tidak
          // menyeret repaint seluruh halaman (hindari jank saat startup).
          child: RepaintBoundary(
            child: Lottie.asset(
              _lottieAsset,
              controller: _controller,
              repeat: false,
              fit: BoxFit.contain,
              // Fallback kalau aset rusak / belum ter-bundle.
              errorBuilder: (_, _, _) => Center(
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x5529D8E4),
                        blurRadius: 32,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Image.asset(
                      'assets/branding/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  _buildAnimation(),
                ],
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: _titleFade,
                child: const Text(
                  'TenMu',
                  style: TextStyle(
                    color: Color(0xFFF3F8FA),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: FadeTransition(
                  opacity: _taglineFade,
                  child: const Text(
                    'Temukan tempat belanja dan destinasi menarik di sekitarmu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xB3EAF5F7),
                      fontSize: 13,
                      letterSpacing: 0.4,
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
