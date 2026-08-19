import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kPrimary      = Color(0xFF1E7A52);
const kAccentRed    = Color(0xFFEF4444);
const kPageBg       = Color(0xFFF3F4F6);
const kCardBg       = Color(0xFFFFFFFF);
const kBorderColor  = Color(0xFFE5E7EB);
const kTextPrimary  = Color(0xFF111827);
const kTextSecondary= Color(0xFF6B7280);
const kTextMuted    = Color(0xFF9CA3AF);
const kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));


// ── Sheet untuk tambah kategori ──────────────────────────────
class AddKategoriSheet extends StatefulWidget {
  final VoidCallback onAdded;

  const AddKategoriSheet({super.key, required this.onAdded});

  @override
  State<AddKategoriSheet> createState() => AddKategoriSheetState();
}

class AddKategoriSheetState extends State<AddKategoriSheet> {
  final _namaController = TextEditingController();
  final _emojiController = TextEditingController(text: '📍');
  final _deskripsiController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _emojiController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _addKategori() async {
    if (_namaController.text.trim().isEmpty) {
      _toast('Nama kategori tidak boleh kosong.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('kategori').insert({
        'nama': _namaController.text.trim(),
        'emoji': _emojiController.text.trim(),
        'deskripsi': _deskripsiController.text.trim().isEmpty
            ? null
            : _deskripsiController.text.trim(),
      });

      if (mounted) {
        _toast('Kategori berhasil ditambahkan.', isError: false);
        widget.onAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      _toast('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {required bool isError}) {
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
    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20, 24, 20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tambah Kategori Baru',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 20),
            Text('Nama Kategori',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _namaController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Contoh: Cafe, Resto, Wisata',
                hintStyle: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 13),
                fillColor: kPageBg, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Emoji (Opsional)',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _emojiController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontSize: 18),
              maxLength: 2,
              decoration: InputDecoration(
                hintText: '📍',
                hintStyle: GoogleFonts.plusJakartaSans(color: kTextMuted),
                fillColor: kPageBg, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Deskripsi (Opsional)',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _deskripsiController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Jelaskan kategori ini...',
                hintStyle: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 13),
                fillColor: kPageBg, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextSecondary,
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Batal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addKategori,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Tambah', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet untuk edit kategori ────────────────────────────────
class EditKategoriSheet extends StatefulWidget {
  final Map<String, dynamic> kategori;
  final VoidCallback onUpdated;

  const EditKategoriSheet({super.key, required this.kategori, required this.onUpdated});

  @override
  State<EditKategoriSheet> createState() => EditKategoriSheetState();
}

class EditKategoriSheetState extends State<EditKategoriSheet> {
  late TextEditingController _namaController;
  late TextEditingController _emojiController;
  late TextEditingController _deskripsiController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.kategori['nama'] ?? '');
    _emojiController = TextEditingController(text: widget.kategori['emoji'] ?? '📍');
    _deskripsiController = TextEditingController(text: widget.kategori['deskripsi'] ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emojiController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _updateKategori() async {
    if (_namaController.text.trim().isEmpty) {
      _toast('Nama kategori tidak boleh kosong.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('kategori')
          .update({
            'nama': _namaController.text.trim(),
            'emoji': _emojiController.text.trim(),
            'deskripsi': _deskripsiController.text.trim().isEmpty
                ? null
                : _deskripsiController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.kategori['id']);

      if (mounted) {
        _toast('Kategori berhasil diperbarui.', isError: false);
        widget.onUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      _toast('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {required bool isError}) {
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
    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20, 24, 20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit Kategori',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 20),
            Text('Nama Kategori',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _namaController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary),
              decoration: InputDecoration(
                fillColor: kPageBg, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Emoji',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _emojiController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontSize: 18),
              maxLength: 2,
              decoration: InputDecoration(
                fillColor: kPageBg, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Deskripsi',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _deskripsiController,
              style: GoogleFonts.plusJakartaSans(color: kTextPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                fillColor: kPageBg, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextSecondary,
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Batal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateKategori,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Simpan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}