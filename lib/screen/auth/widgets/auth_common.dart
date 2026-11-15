import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart' as ac;
import '../../../core/app_colors_light.dart' as acl;
import '../../../core/theme_provider.dart';
import 'legal_sheet.dart';

/// Palet & widget bersama untuk semua layar auth (Login, Daftar, OTP, Lupa Password).
/// Tujuan: tampilan konsisten dan kode tidak terduplikasi.
///
/// Palet ini **mengikuti tema aktif** ([ThemeProvider]) lewat [AuthPalette.of],
/// supaya tombol ganti tema di halaman login langsung terlihat hasilnya dan
/// pilihan itu (disimpan di `SharedPreferences` oleh [ThemeProvider]) ikut
/// terbawa ke beranda setelah user masuk.
class AuthPalette {
  const AuthPalette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.grey,
    required this.hint,
    required this.border,
    required this.divider,
    required this.btn,
    required this.btnLabel,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color grey;
  final Color hint;
  final Color border;
  final Color divider;
  final Color btn;
  final Color btnLabel;

  static const AuthPalette dark = AuthPalette(
    bg: ac.AppColors.bgBase,
    surface: ac.AppColors.bgElevated,
    ink: ac.AppColors.textPrimary,
    grey: ac.AppColors.textSecondary,
    hint: ac.AppColors.textHint,
    border: ac.AppColors.border,
    divider: ac.AppColors.divider,
    btn: ac.AppColors.btnPrimary,
    btnLabel: ac.AppColors.btnLabel,
  );

  static const AuthPalette light = AuthPalette(
    bg: acl.AppColorsLight.bgBase,
    surface: acl.AppColorsLight.bgElevated,
    ink: acl.AppColorsLight.textPrimary,
    grey: acl.AppColorsLight.textSecondary,
    hint: acl.AppColorsLight.textHint,
    border: acl.AppColorsLight.border,
    divider: acl.AppColorsLight.divider,
    btn: acl.AppColorsLight.btnPrimary,
    btnLabel: acl.AppColorsLight.btnLabel,
  );

  /// Palet sesuai tema yang sedang aktif.
  static AuthPalette of(BuildContext context) =>
      context.watch<ThemeProvider>().isDarkMode ? dark : light;
}

/// Input field bergaya TenMu (dark) — dipakai di semua form auth.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final List<String>? autofillHints;
  final bool autofocus;
  final int? maxLength;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
    this.autofocus = false,
    this.maxLength,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      autofocus: autofocus,
      maxLength: maxLength,
      style: TextStyle(color: p.ink),
      cursorColor: p.btn,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: p.grey, fontSize: 14),
        hintText: hint,
        hintStyle: TextStyle(color: p.hint),
        errorText: errorText,
        counterText: '',
        prefixIcon: Icon(icon, color: p.grey, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _border(p.border),
        enabledBorder: _border(p.border),
        disabledBorder: _border(p.border.withValues(alpha: 0.5)),
        focusedBorder: _border(p.ink, 1.5),
        errorBorder: _border(Colors.redAccent),
        focusedErrorBorder: _border(Colors.redAccent, 1.5),
      ),
    );
  }
}

/// Checkbox syarat & ketentuan.
/// Teks "Ketentuan Layanan" & "Kebijakan Privasi" bisa DIKLIK → muncul pop-up.
class AuthTermsCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const AuthTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<AuthTermsCheckbox> createState() => _AuthTermsCheckboxState();
}

class _AuthTermsCheckboxState extends State<AuthTermsCheckbox> {
  late final TapGestureRecognizer _toggle1;
  late final TapGestureRecognizer _toggle2;
  late final TapGestureRecognizer _toggle3;
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _toggle1 = TapGestureRecognizer()..onTap = _toggle;
    _toggle2 = TapGestureRecognizer()..onTap = _toggle;
    _toggle3 = TapGestureRecognizer()..onTap = _toggle;
    _terms = TapGestureRecognizer()
      ..onTap = () => showLegalSheet(context, LegalDoc.terms);
    _privacy = TapGestureRecognizer()
      ..onTap = () => showLegalSheet(context, LegalDoc.privacy);
  }

  void _toggle() {
    final cb = widget.onChanged;
    if (cb == null) return;
    cb(!widget.value);
  }

  @override
  void dispose() {
    _toggle1.dispose();
    _toggle2.dispose();
    _toggle3.dispose();
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final enabled = widget.onChanged != null;
    final linkStyle = TextStyle(
      color: p.ink,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: enabled ? _toggle : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: widget.value,
                onChanged: widget.onChanged,
                activeColor: p.btn,
                checkColor: p.btnLabel,
                side: BorderSide(color: p.hint, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: p.grey, height: 1.4),
                  children: [
                    TextSpan(
                      text: 'Dengan masuk, saya menyetujui ',
                      recognizer: enabled ? _toggle1 : null,
                    ),
                    TextSpan(
                      text: 'Ketentuan Layanan',
                      style: linkStyle,
                      recognizer: _terms,
                    ),
                    TextSpan(
                      text: ' & ',
                      recognizer: enabled ? _toggle2 : null,
                    ),
                    TextSpan(
                      text: 'Kebijakan Privasi',
                      style: linkStyle,
                      recognizer: _privacy,
                    ),
                    TextSpan(
                      text: ' TenMu.',
                      recognizer: enabled ? _toggle3 : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol utama lebar penuh dengan status loading.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  /// Warna opsional; kalau null ikut palet tema aktif.
  final Color? background;
  final Color? foreground;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.loadingLabel = 'Memproses...',
    required this.isLoading,
    required this.onPressed,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final bg = background ?? p.btn;
    final fg = foreground ?? p.btnLabel;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          disabledForegroundColor: fg.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: fg,
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    loadingLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
      ),
    );
  }
}

/// Garis pemisah "atau".
class AuthOrDivider extends StatelessWidget {
  AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: p.divider)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('atau', style: TextStyle(color: p.hint, fontSize: 13)),
        ),
        Expanded(child: Divider(color: p.divider)),
      ],
    );
  }
}

/// Notifikasi ringkas di **atas layar** dengan teks putih (selalu terbaca).
/// Merah = error, hijau = sukses. Auto-hilang 4 detik, tap untuk tutup.
void showAuthSnack(BuildContext context, String msg, {bool isError = true}) {
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AuthTopBanner(
      message: msg,
      isError: isError,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _AuthTopBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  const _AuthTopBanner({
    required this.message,
    required this.isError,
    required this.onDismissed,
  });

  @override
  State<_AuthTopBanner> createState() => _AuthTopBannerState();
}

class _AuthTopBannerState extends State<_AuthTopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _timer?.cancel();
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError
        ? const Color(0xFFD32F2F)
        : const Color(0xFF1DB954);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: SlideTransition(
            position: _slide,
            child: GestureDetector(
              onTap: _dismiss,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAuthErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final p = AuthPalette.of(ctx);
      return Dialog(
        backgroundColor: p.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F0F5),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.5, color: p.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.btn,
                    foregroundColor: p.btnLabel,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom-sheet sukses setelah berhasil masuk/daftar.
/// Otomatis menutup setelah [autoClose] (default 3 detik) → user langsung
/// melihat beranda di belakangnya.
Future<void> showAuthSuccessSheet(
  BuildContext context, {
  required VoidCallback onContinue,
  String title = 'Login Berhasil!',
  String subtitle = 'Selamat datang di TenMu.\nMengarahkan ke beranda...',
  Duration autoClose = const Duration(seconds: 3),
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _SuccessSheet(
      title: title,
      subtitle: subtitle,
      autoClose: autoClose,
      onContinue: () {
        Navigator.of(ctx).pop();
        onContinue();
      },
    ),
  );
}

class _SuccessSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Duration autoClose;
  final VoidCallback onContinue;

  const _SuccessSheet({
    required this.title,
    required this.subtitle,
    required this.autoClose,
    required this.onContinue,
  });

  @override
  State<_SuccessSheet> createState() => _SuccessSheetState();
}

class _SuccessSheetState extends State<_SuccessSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoClose > Duration.zero) {
      _timer = Timer(widget.autoClose, () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.divider,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.btn.withValues(alpha: 0.15),
              border: Border.all(color: p.btn, width: 2),
            ),
            child: Icon(Icons.check_rounded, color: p.btn, size: 52),
          ),
          const SizedBox(height: 20),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: p.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.btn,
                foregroundColor: p.btnLabel,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Lanjutkan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
