import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddKategoriSheet(onAdded: _loadKategori),
    );
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
          style: GoogleFonts.poppins(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Kamu yakin ingin menghapus kategori "${kategori['nama']}"?',
          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text('Hapus', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('kategori').delete().eq('id', kategori['id']);
        await _loadKategori();
        _snack('Kategori berhasil dihapus.', isError: false);
      } catch (e) {
        _snack('Gagal menghapus: $e', isError: true);
      }
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
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
          style: GoogleFonts.poppins(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _openAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('Tambah', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
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
                    style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontWeight: FontWeight.w600)),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 14),
                    ),
                    subtitle: kat['deskripsi'] != null && (kat['deskripsi'] as String).isNotEmpty
                        ? Text(
                            kat['deskripsi'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12),
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