import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../core/theme_provider.dart';
import '../../core/lucide_icons.dart';
import 'settings/widgets/delete_account_section.dart';

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
  Uint8List? _selectedImageBytes;

  String? _currentRole;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _namaController.text =
        user?.userMetadata?['full_name'] ?? user?.userMetadata?['nama'] ?? '';
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null) {
        setState(() {
          _currentRole = profileData['role']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Failed to load role: $e');
    }
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
    final bytes = await pickedFile.readAsBytes();

    setState(() {
      _selectedImageBytes = bytes;
      _isUploadingImage = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final fileName =
          'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload ke bucket profiles
      await Supabase.instance.client.storage
          .from('profiles')
          .uploadBinary(fileName, _selectedImageBytes!,
              fileOptions: FileOptions(contentType: 'image/jpeg'));

      final imageUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': imageUrl}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil diperbarui! ✅'),
            backgroundColor: Colors.green,
          ),
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
        if (_passwordController.text.length < 6) {
          throw 'Password min 6 karakter';
        }
        attributes = UserAttributes(
          data: updates,
          password: _passwordController.text.trim(),
        );
      }

      await Supabase.instance.client.auth.updateUser(attributes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil diperbarui! ✅'),
            backgroundColor: Colors.green,
          ),
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
        title: Text(
          'Pengaturan Profil',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                    backgroundImage: _selectedImageBytes != null
                        ? MemoryImage(_selectedImageBytes!)
                        : (currentAvatar != null
                                  ? NetworkImage(currentAvatar)
                                  : null)
                              as ImageProvider?,
                    child: _selectedImageBytes == null && currentAvatar == null
                        ? LucideIcon('user', size: 50, color: theme.iconColor)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const LucideIcon('camera',
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ),
                  ),
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
                prefixIcon: LucideIcon('mail', color: theme.iconColor),
                filled: true,
                fillColor: theme.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _namaController,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                labelStyle: TextStyle(color: theme.textSecondary),
                prefixIcon: LucideIcon('user', color: theme.iconColor),
                filled: true,
                fillColor: theme.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.borderFocus),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Role info
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Role Akun',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  LucideIcon(
                    _currentRole == 'owner'
                        ? 'store'
                        : 'user',
                    color: theme.iconColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _currentRole == 'owner'
                        ? 'Pemilik UMKM'
                        : 'User Biasa',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                prefixIcon: LucideIcon('lock', color: theme.iconColor),
                filled: true,
                fillColor: theme.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.borderFocus),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.btnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          color: theme.btnLabel,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const DeleteAccountSection(),
          ],
        ),
      ),
    );
  }
}
