import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class AddUmkmScreen extends StatefulWidget {
  const AddUmkmScreen({super.key});

  @override
  State<AddUmkmScreen> createState() => _AddUmkmScreenState();
}

class _AddUmkmScreenState extends State<AddUmkmScreen> {
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _alamatController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _isFeatured = false;
  bool _isLoading = false;
  File? _imageFile;

  // Fungsi untuk memilih gambar dari galeri
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Fungsi utama untuk menyimpan data
  Future<void> _simpanData() async {
    // Validasi sederhana
    if (_namaController.text.isEmpty || _alamatController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Alamat wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;

      // 1. Jika ada gambar, upload dulu ke Supabase Storage
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = fileName; // path di dalam bucket

        await Supabase.instance.client.storage
            .from('umkm_images')
            .upload(filePath, _imageFile!);

        // Ambil URL publik dari gambar yang baru diupload
        imageUrl = Supabase.instance.client.storage
            .from('umkm_images')
            .getPublicUrl(filePath);
      }

      // 2. Simpan data teks + URL gambar ke tabel umkm
      await Supabase.instance.client.from('umkm').insert({
        'nama_tempat': _namaController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text.trim()),
        'longitude': double.tryParse(_longitudeController.text.trim()),
        'gambar_url': imageUrl,
        'is_featured': _isFeatured,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data Tempat Nongkrong berhasil ditambahkan!'),
          ),
        );
        Navigator.pop(context); // Kembali ke halaman sebelumnya
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Tempat Baru')),
      // SingleChildScrollView agar form bisa di-scroll jika keyboard muncul
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Area Preview Gambar
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Ketuk untuk pilih gambar'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Tempat Nongkrong*',
              ),
            ),
            TextField(
              controller: _deskripsiController,
              decoration: const InputDecoration(labelText: 'Deskripsi Singkat'),
              maxLines: 3,
            ),
            TextField(
              controller: _alamatController,
              decoration: const InputDecoration(labelText: 'Alamat Lengkap*'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude (Opsional)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude (Opsional)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Jadikan Tempat Unggulan (Featured)?'),
              value: _isFeatured,
              onChanged: (bool value) {
                setState(() => _isFeatured = value);
              },
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _simpanData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Simpan Data',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
