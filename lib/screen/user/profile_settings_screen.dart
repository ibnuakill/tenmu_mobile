import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme_provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _namaController.text = user?.userMetadata?['full_name'] ?? user?.userMetadata?['nama'] ?? '';
  }

  @override
  void dispose() {
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _isUploadingImage = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final fileName = 'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload ke bucket profiles
      await Supabase.instance.client.storage
          .from('profiles')
          .upload(fileName, _selectedImage!);

      final imageUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'avatar_url': imageUrl},
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil diperbarui! ✅'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{};
      if (_namaController.text.isNotEmpty) {
        updates['full_name'] = _namaController.text.trim();
      }

      UserAttributes attributes = UserAttributes(data: updates);

      if (_passwordController.text.isNotEmpty) {
        if (_passwordController.text.length < 6) throw 'Password min 6 karakter';
        attributes = UserAttributes(
          data: updates,
          password: _passwordController.text.trim()
        );
      }

      await Supabase.instance.client.auth.updateUser(attributes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil diperbarui! ✅'), backgroundColor: Colors.green),
        );
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final user = Supabase.instance.client.auth.currentUser;
    final currentAvatar = user?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        title: Text('Pengaturan Profil', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.bgElevated,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (currentAvatar != null ? NetworkImage(currentAvatar) : null) as ImageProvider?,
                    child: _selectedImage == null && currentAvatar == null
                        ? Icon(Icons.person, size: 50, color: theme.iconColor)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: _isUploadingImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: user?.email),
              style: TextStyle(color: theme.textSecondary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: theme.textHint),
                prefixIcon: Icon(Icons.email, color: theme.iconColor),
                filled: true,
                fillColor: theme.bgElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _namaController,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                labelStyle: TextStyle(color: theme.textSecondary),
                prefixIcon: Icon(Icons.person, color: theme.iconColor),
                filled: true,
                fillColor: theme.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderFocus)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password Baru (Kosongkan jika tidak diubah)',
                labelStyle: TextStyle(color: theme.textSecondary),
                prefixIcon: Icon(Icons.lock, color: theme.iconColor),
                filled: true,
                fillColor: theme.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderFocus)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: theme.btnPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('Simpan Perubahan', style: TextStyle(color: theme.btnLabel, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
