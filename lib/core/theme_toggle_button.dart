import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: () => themeProvider.toggleTheme(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeProvider.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.border),
            ),
            child: Icon(
              themeProvider.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: themeProvider.iconColor,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
