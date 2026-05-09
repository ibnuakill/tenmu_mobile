import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_colors_light.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  static const String _themeKey = 'isDarkMode';

  ThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;

  // Getter untuk warna yang aktif
  Color get bgBase => _isDarkMode ? AppColors.bgBase : AppColorsLight.bgBase;
  Color get bgSurface => _isDarkMode ? AppColors.bgSurface : AppColorsLight.bgSurface;
  Color get bgElevated => _isDarkMode ? AppColors.bgElevated : AppColorsLight.bgElevated;
  Color get border => _isDarkMode ? AppColors.border : AppColorsLight.border;
  Color get borderFocus => _isDarkMode ? AppColors.borderFocus : AppColorsLight.borderFocus;
  Color get textPrimary => _isDarkMode ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get textSecondary => _isDarkMode ? AppColors.textSecondary : AppColorsLight.textSecondary;
  Color get textHint => _isDarkMode ? AppColors.textHint : AppColorsLight.textHint;
  Color get iconColor => _isDarkMode ? AppColors.iconColor : AppColorsLight.iconColor;
  Color get btnPrimary => _isDarkMode ? AppColors.btnPrimary : AppColorsLight.btnPrimary;
  Color get btnLabel => _isDarkMode ? AppColors.btnLabel : AppColorsLight.btnLabel;
  Color get snackError => _isDarkMode ? AppColors.snackError : AppColorsLight.snackError;
  Color get snackSuccess => _isDarkMode ? AppColors.snackSuccess : AppColorsLight.snackSuccess;
  Color get snackErrorBorder => _isDarkMode ? AppColors.snackErrorBorder : AppColorsLight.snackErrorBorder;
  Color get snackSuccessBorder => _isDarkMode ? AppColors.snackSuccessBorder : AppColorsLight.snackSuccessBorder;
  Color get divider => _isDarkMode ? AppColors.divider : AppColorsLight.divider;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
}
