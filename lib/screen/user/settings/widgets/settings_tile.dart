import 'package:flutter/material.dart';
import '../../../../core/theme_provider.dart';

/// Section header (uppercase tracking).
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final ThemeProvider theme;
  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// Rounded surface card yang membungkus list of tiles.
class SettingsCard extends StatelessWidget {
  final ThemeProvider theme;
  final List<Widget> children;
  const SettingsCard({
    super.key,
    required this.theme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.18),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

/// Standard leading icon chip (40x40, tinted background).
class _LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _LeadingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Reusable 2-line label (title + subtitle) yang dipake di banyak tile.
class _TwoLineLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final ThemeProvider theme;
  const _TwoLineLabel({
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: theme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// Switch tile (icon + label + switch.adaptive).
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeProvider theme;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _LeadingIcon(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: _TwoLineLabel(
              title: title,
              subtitle: subtitle,
              theme: theme,
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.btnPrimary,
            inactiveTrackColor: theme.bgElevated,
          ),
        ],
      ),
    );
  }
}

/// Navigation tile (icon + label + chevron).
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _LeadingIcon(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: _TwoLineLabel(
                title: title,
                subtitle: subtitle,
                theme: theme,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.textHint, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Action tile (icon + label, no trailing widget — bisa loading).
class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _LeadingIcon(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: _TwoLineLabel(
                title: title,
                subtitle: subtitle,
                theme: theme,
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown / picker tile (icon + label + expand_more).
class SettingsDropdownTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const SettingsDropdownTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _LeadingIcon(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: _TwoLineLabel(
                title: title,
                subtitle: subtitle,
                theme: theme,
              ),
            ),
            Icon(Icons.expand_more_rounded, color: theme.textHint, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Single selectable row di dalam bottom sheet (untuk unit picker dll.).
class SettingsPickerOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const SettingsPickerOption({
    super.key,
    required this.title,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? theme.btnPrimary : theme.textPrimary,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.btnPrimary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet container standar untuk picker (drag handle + title).
class PickerBottomSheet extends StatelessWidget {
  final String title;
  final ThemeProvider theme;
  final List<Widget> options;
  const PickerBottomSheet({
    super.key,
    required this.title,
    required this.theme,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.borderFocus,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...options,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
