import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

/// 3-slide onboarding — muncul sekali setelah splash, sebelum login.
/// Selesai → tandai di SharedPreferences → navigasi ke LoginScreen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Cek apakah onboarding sudah pernah ditandai selesai.
  static Future<bool> isCompleted() async {
    const key = 'onboarding_completed';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _onboardingKey = 'onboarding_completed';
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Color(0xB3EAF5F7),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Pages ────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildPage(
                      icon: Icons.explore_outlined,
                      title: 'Temukan Tempat Nongkrong',
                      description:
                          'Jelajahi berbagai tempat keren di sekitarmu. '
                          'Dari kafe cozy hingga tempat wisata seru — '
                          'semua ada di sini.',
                    ),
                    _buildPage(
                      icon: Icons.verified_outlined,
                      title: 'Terverifikasi & Terpercaya',
                      description:
                          'Semua tempat sudah terverifikasi. '
                          'Dapatkan info akurat tentang jam buka, '
                          'fasilitas, dan rating dari pengunjung.',
                    ),
                    _buildPage(
                      icon: Icons.map_outlined,
                      title: 'Mau Jalan-jalan?',
                      description:
                          'Tentukan tujuan, lihat rute, dan mulai '
                          'petualanganmu. TenMu siap jadi teman '
                          'nongkrongmu!',
                    ),
                  ],
                ),
              ),

              // ── Indicators + Button ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? const Color(0xFF29D8E4)
                                : const Color(0x4D29D8E4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage < 2) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1ED760),
                            foregroundColor: const Color(0xFF121212),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage < 2 ? 'Lanjut' : 'Mulai',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x2229D8E4),
            ),
            child: Icon(icon, size: 56, color: const Color(0xFF29D8E4)),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF3F8FA),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xB3EAF5F7),
              fontSize: 15,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
