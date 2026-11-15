import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenmu/core/app_colors.dart' as ac;
import 'package:tenmu/core/app_colors_light.dart' as acl;
import 'package:tenmu/core/theme_provider.dart';
import 'package:tenmu/screen/auth/widgets/auth_common.dart';

/// Memastikan palet layar auth (login, daftar, OTP, lupa password) mengikuti
/// tema aktif — jadi tombol ganti tema di halaman login langsung terlihat
/// hasilnya dan pilihan itu tetap dipakai setelah user masuk ke beranda.
void main() {
  testWidgets('AuthPalette ikut tema yang sedang aktif', (tester) async {
    SharedPreferences.setMockInitialValues({'isDarkMode': false});
    final theme = ThemeProvider();
    await theme.setTheme(false);

    late AuthPalette awal;
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              awal = AuthPalette.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(awal.bg, acl.AppColorsLight.bgBase);
    expect(awal.ink, acl.AppColorsLight.textPrimary);
    final awalBg = awal.bg;

    // Ganti ke gelap → palet harus ikut berganti tanpa ganti halaman.
    await theme.setTheme(true);
    await tester.pump();

    late AuthPalette akhir;
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              akhir = AuthPalette.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(akhir.bg, ac.AppColors.bgBase);
    expect(akhir.ink, ac.AppColors.textPrimary);
    expect(akhir.bg, isNot(awalBg));
  });

  test(
    'pilihan tema tersimpan di SharedPreferences (ikut sesi berikutnya)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeProvider();
      await theme.setTheme(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), false);

      await theme.setTheme(true);
      expect(prefs.getBool('isDarkMode'), true);
    },
  );
}
