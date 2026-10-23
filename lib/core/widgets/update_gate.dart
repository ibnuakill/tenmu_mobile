import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_update_provider.dart';
import '../app_update_service.dart';
import 'update_dialog.dart';

/// Memeriksa pembaruan saat aplikasi dibuka dan menampilkan dialog bila
/// ada versi baru yang tersedia.
///
/// Menempatkan widget ini di atas aplikasi membuat dialog tampil di atas
/// segalanya tanpa perlu pindah screen.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    // Delay singkat supaya splash selesai sebelum request jaringan jalan.
    Future.delayed(const Duration(milliseconds: 1200), _checkUpdate);
  }

  Future<void> _checkUpdate() async {
    if (!mounted) return;
    await context.read<AppUpdateProvider>().checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppUpdateProvider, UpdateStatus>(
      (p) => p.status,
    );

    if (status == UpdateStatus.updateAvailable && !_dialogVisible) {
      _dialogVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await UpdateDialog.show(context);
        if (!mounted) return;
        setState(() => _dialogVisible = false);
      });
    }

    return widget.child;
  }
}
