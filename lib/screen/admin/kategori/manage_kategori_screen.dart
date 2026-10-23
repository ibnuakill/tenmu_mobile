import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/kategori_sheets.dart';

class ManageKategoriScreen extends StatefulWidget {
  const ManageKategoriScreen({super.key});

  @override
  State<ManageKategoriScreen> createState() => _ManageKategoriScreenState();
}

class _ManageKategoriScreenState extends State<ManageKategoriScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _kategoriList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKategori();
  }

  Future<void> _loadKategori() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('kategori')
          .select()
          .order('nama', ascending: true);

      setState(() {
        _kategoriList = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      _snack('Gagal memuat kategori: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _openEditSheet(Map<String, dynamic> kategori) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          EditKategoriSheet(kategori: kategori, onUpdated: _loadKategori),
    );
  }

  Future<void> _deleteKategori(Map<String, dynamic> kategori) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Kategori?',
          style: TextStyle(fontFamily: 'Nunito', color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Kategori "${kategori['nama']}" adalah sektor baku dan tidak bisa dihapus. '
          'Hanya deskripsi dan emoji yang bisa diubah.',
          style: TextStyle(fontFamily: 'Nunito', color: kTextSecondary, height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(fontFamily: 'Nunito', color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text('Mengerti', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _snack('5 kategori sektor bersifat baku dan tidak bisa dihapus.', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontFamily: 'Nunito', color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? kAccentRed : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Kelola Kategori',
          style: TextStyle(fontFamily: 'Nunito', 
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: '5 kategori sektor bersifat baku',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: kPrimary, size: 14),
                    const SizedBox(width: 4),
                    Text('5 Sektor Baku',
                        style: TextStyle(fontFamily: 'Nunito', color: kPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
          : _kategoriList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_outlined, size: 44, color: kPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text('Belum ada kategori.',
                    style: TextStyle(fontFamily: 'Nunito', color: kTextSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _kategoriList.length,
              itemBuilder: (context, index) {
                final kat = _kategoriList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                    boxShadow: const [kShadow],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
                      ),
                      child: Center(
                        child: Text(
                          kat['emoji'] ?? '📍',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    title: Text(
                      kat['nama'] ?? '-',
                      style: TextStyle(fontFamily: 'Nunito', 
                        fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 14),
                    ),
                    subtitle: kat['deskripsi'] != null && (kat['deskripsi'] as String).isNotEmpty
                        ? Text(
                            kat['deskripsi'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Nunito', color: kTextSecondary, fontSize: 12),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconBtn(
                          icon: Icons.edit_outlined,
                          color: kPrimary,
                          onTap: () => _openEditSheet(kat),
                        ),
                        const SizedBox(width: 6),
                        _iconBtn(
                          icon: Icons.delete_outline_rounded,
                          color: kAccentRed,
                          onTap: () => _deleteKategori(kat),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}