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
  final _requestMessageController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isRequestLoading = false;
  File? _selectedImage;

  String? _currentRole;
  String? _requestStatus;
  DateTime? _requestCreatedAt;
  String? _requestMessage;
  String? _requestHandledAt;
  String? _requestHandledBy;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _namaController.text =
        user?.userMetadata?['full_name'] ?? user?.userMetadata?['nama'] ?? '';
    _loadProfileRequestInfo();
  }

  Future<void> _loadProfileRequestInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select(
            'role, request_status, request_message, request_created_at, request_handled_at, request_handled_by',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null) {
        setState(() {
          _currentRole = profileData['role']?.toString();
          _requestStatus = profileData['request_status']?.toString();
          _requestMessage = profileData['request_message']?.toString();
          _requestCreatedAt = profileData['request_created_at'] != null
              ? DateTime.tryParse(profileData['request_created_at'])
              : null;
          _requestHandledAt = profileData['request_handled_at']?.toString();
          _requestHandledBy = profileData['request_handled_by']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Failed to load request info: $e');
    }
  }

  Future<void> _submitRoleRequest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_requestMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tolong isi alasan permintaan terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRequestLoading = true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'requested_role': 'owner',
            'request_message': _requestMessageController.text.trim(),
            'request_status': 'pending',
            'request_created_at': DateTime.now().toIso8601String(),
            'request_handled_by': null,
            'request_handled_at': null,
          })
          .eq('id', user.id);

      setState(() {
        _requestStatus = 'pending';
        _requestMessage = _requestMessageController.text.trim();
        _requestCreatedAt = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permintaan role owner berhasil dikirim. Tunggu verifikasi admin.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim permintaan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequestLoading = false);
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

    setState(() {
      _selectedImage = File(pickedFile.path);
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
          .upload(fileName, _selectedImage!);

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
        if (_passwordController.text.length < 6)
          throw 'Password min 6 karakter';
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
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (currentAvatar != null
                                  ? NetworkImage(currentAvatar)
                                  : null)
                              as ImageProvider?,
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
                            : const Icon(
                                Icons.camera_alt,
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
                prefixIcon: Icon(Icons.email, color: theme.iconColor),
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
                prefixIcon: Icon(Icons.person, color: theme.iconColor),
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
            if (_currentRole == 'user') ...[
              if (_requestStatus == null || _requestStatus == 'rejected') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ajukan permintaan menjadi pemilik UMKM',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _requestMessageController,
                  maxLines: 3,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Alasan Anda ingin jadi owner',
                    labelStyle: TextStyle(color: theme.textSecondary),
                    fillColor: theme.bgSurface,
                    filled: true,
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isRequestLoading ? null : _submitRoleRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.btnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isRequestLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Ajukan Request Owner',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_requestStatus == 'pending') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Permintaan',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Permintaan sedang menunggu verifikasi admin.',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                      if (_requestMessage != null &&
                          _requestMessage!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Pesan: $_requestMessage',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_requestStatus == 'rejected') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB71C1C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permintaan Ditolak',
                        style: TextStyle(
                          color: const Color(0xFFB71C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Alasan: ${_requestMessage ?? '-'}',
                        style: TextStyle(color: const Color(0xFFB71C1C)),
                      ),
                      if (_requestHandledAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Diperbarui: $_requestHandledAt',
                          style: TextStyle(
                            color: const Color(0xFFB71C1C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
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
          ],
        ),
      ),
    );
  }
}
