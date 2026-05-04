import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditUmkmScreen extends StatefulWidget {
  final Map<String, dynamic> umkm;

  const EditUmkmScreen({super.key, required this.umkm});

  @override
  State<EditUmkmScreen> createState() => _EditUmkmScreenState();
}

class _EditUmkmScreenState extends State<EditUmkmScreen> {
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Isi otomatis form dengan data yang sudah ada
    _namaController.text = widget.umkm['nama_tempat'] ?? '';
    _alamatController.text = widget.umkm['alamat'] ?? '';
    _deskripsiController.text = widget.umkm['deskripsi'] ?? '';
    _latController.text = widget.umkm['latitude']?.toString() ?? '';
    _lngController.text = widget.umkm['longitude']?.toString() ?? '';
  }

  Future<void> _updateData() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('umkm')
          .update({
            'nama_tempat': _namaController.text,
            'alamat': _alamatController.text,
            'deskripsi': _deskripsiController.text,
            'latitude': double.tryParse(_latController.text),
            'longitude': double.tryParse(_lngController.text),
          })
          .eq('id', widget.umkm['id']); // Update berdasarkan ID data tersebut

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke halaman kelola
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Tempat Nongkrong')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Tempat'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alamatController,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deskripsiController,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lngController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateData,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
