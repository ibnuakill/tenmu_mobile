// Desktop init: window manager & fullscreen hotkey.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Jendela desktop dibuka dalam mode fullscreen borderless (diterapkan di
/// `windows/runner/flutter_window.cpp` SEBELUM view Flutter dibuat, supaya
/// surface pertama langsung seukuran layar dan tidak tampil hitam).
///
/// Fungsi ini hanya memasang hotkey F11 / Esc untuk keluar-masuk fullscreen.
Future<void> setupDesktop() async {
  // Di Android/iOS plugin `window_manager` tidak punya implementasi → kalau
  // dipanggil akan melempar MissingPluginException dan menggagalkan main()
  // sebelum runApp() (layar hitam).
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  await WindowManager.instance.ensureInitialized();

  // Runner native sudah membuka jendela dalam fullscreen, jadi state awal = true.
  var isFull = true;

  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.f11)) {
      isFull = !isFull;
      unawaited(() async {
        try {
          await WindowManager.instance.setFullScreen(isFull);
        } catch (_) {}
      }());
    }
    return false;
  });
}
