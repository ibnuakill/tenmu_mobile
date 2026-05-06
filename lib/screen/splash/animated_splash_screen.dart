import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const AnimatedSplashScreen({super.key, required this.nextScreen});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoVerticalOffsetAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _textFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 1.0, curve: Curves.easeOut),
    );
    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );
    _logoVerticalOffsetAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 360,
          end: -20,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 86,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -20,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
    ]).animate(_controller);

    _controller.forward();
    _navigationTimer = Timer(const Duration(milliseconds: 2450), _goNext);
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

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _controller,
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
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _logoVerticalOffsetAnimation.value),
          child: FadeTransition(
            opacity: _logoFadeAnimation,
            child: ScaleTransition(
              scale: _logoScaleAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E2329),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D121F),
              Color(0xFF134C57),
            ],
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(-1.15, -1.1),
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x3329D8E4),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.9, 1.0),
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2229D8E4),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedLogo(),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _textFadeAnimation,
                      child: const Column(
                        children: [
                          Text(
                            'TenMu',
                            style: TextStyle(
                              color: Color(0xFFF3F8FA),
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Temukan tempat nongkrong favoritmu',
                            style: TextStyle(
                              color: Color(0xB3EAF5F7),
                              fontSize: 13,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
