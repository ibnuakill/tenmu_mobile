import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Quixotic Palette
const kPrimary      = Color(0xFF1E7A52);
const kAccentGreen  = Color(0xFF0FA968);
const kAccentRed    = Color(0xFFEF4444);
const kPageBg       = Color(0xFFF3F4F6);
const kCardBg       = Color(0xFFFFFFFF);
const kBorderColor  = Color(0xFFE5E7EB);
const kTextPrimary  = Color(0xFF111827);
const kTextSecondary= Color(0xFF6B7280);
const kTextMuted    = Color(0xFF9CA3AF);
const kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));

// ── Info Card Admin ─────────────────────────────────────────────────────────
class AdminInfoCard extends StatelessWidget {
  final String email;
  const AdminInfoCard({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: kPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin TenMu',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: kTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String title;
  const SectionLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: kTextMuted,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Container Card ───────────────────────────────────────────────────────────
class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Column(children: children),
    );
  }
}

// ── Nav Tile ─────────────────────────────────────────────────────────────────
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
        style: GoogleFonts.plusJakartaSans(
          color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle,
        style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: kTextMuted, size: 20),
    );
  }
}

// ── Action Tile ──────────────────────────────────────────────────────────────
class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isLoading ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
        style: GoogleFonts.plusJakartaSans(
          color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle,
        style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12)),
      trailing: isLoading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded, color: kTextMuted, size: 20),
    );
  }
}