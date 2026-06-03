import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';

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
      builder: (_) => _AddKategoriSheet(onAdded: _loadKategori),
    );
  }

  void _openEditSheet(Map<String, dynamic> kategori) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditKategoriSheet(kategori: kategori, onUpdated: _loadKategori),
    );
  }

  Future<void> _deleteKategori(Map<String, dynamic> kategori) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Kategori?',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Kamu yakin ingin menghapus kategori "${kategori['nama']}"?',
          style: TextStyle(color: theme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? theme.snackErrorBorder : theme.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: theme.textPrimary,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Kelola Kategori',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _openAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.btnPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_rounded, color: theme.btnLabel, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.iconColor))
          : _kategoriList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 56,
                    color: theme.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada kategori.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _kategoriList.length,
              itemBuilder: (context, index) {
                final kat = _kategoriList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border),
                      ),
                      child: Center(
                        child: Text(
                          kat['emoji'] ?? '📍',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      kat['nama'] ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    subtitle:
                        kat['deskripsi'] != null && kat['deskripsi']!.isNotEmpty
                        ? Text(
                            kat['deskripsi'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconBtn(
                          icon: Icons.edit_outlined,
                          color: theme.borderFocus,
                          onTap: () => _openEditSheet(kat),
                        ),
                        const SizedBox(width: 6),
                        _iconBtn(
                          icon: Icons.delete_outline,
                          color: const Color(0xFF8B2020),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Sheet untuk tambah kategori ──────────────────────────────
class _AddKategoriSheet extends StatefulWidget {
  final VoidCallback onAdded;

  const _AddKategoriSheet({required this.onAdded});

  @override
  State<_AddKategoriSheet> createState() => _AddKategoriSheetState();
}

class _AddKategoriSheetState extends State<_AddKategoriSheet> {
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tambah Kategori Baru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nama Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _namaController,
              style: TextStyle(color: theme.textPrimary),
              cursorColor: theme.borderFocus,
              decoration: InputDecoration(
                hintText: 'Contoh: Cafe, Warung, etc',
                hintStyle: TextStyle(color: theme.textHint),
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Emoji (Opsional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emojiController,
              style: TextStyle(color: theme.textPrimary, fontSize: 16),
              cursorColor: theme.borderFocus,
              maxLength: 2,
              decoration: InputDecoration(
                hintText: '📍',
                hintStyle: TextStyle(color: theme.textHint),
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Deskripsi (Opsional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deskripsiController,
              style: TextStyle(color: theme.textPrimary),
              cursorColor: theme.borderFocus,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Jelaskan kategori ini...',
                hintStyle: TextStyle(color: theme.textHint),
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.bgElevated,
                      foregroundColor: theme.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: theme.border),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addKategori,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.btnPrimary,
                      foregroundColor: theme.btnLabel,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.btnLabel,
                            ),
                          )
                        : const Text('Tambah'),
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
class _EditKategoriSheet extends StatefulWidget {
  final Map<String, dynamic> kategori;
  final VoidCallback onUpdated;

  const _EditKategoriSheet({required this.kategori, required this.onUpdated});

  @override
  State<_EditKategoriSheet> createState() => _EditKategoriSheetState();
}

class _EditKategoriSheetState extends State<_EditKategoriSheet> {
  late TextEditingController _namaController;
  late TextEditingController _emojiController;
  late TextEditingController _deskripsiController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(
      text: widget.kategori['nama'] ?? '',
    );
    _emojiController = TextEditingController(
      text: widget.kategori['emoji'] ?? '📍',
    );
    _deskripsiController = TextEditingController(
      text: widget.kategori['deskripsi'] ?? '',
    );
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Kategori',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nama Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _namaController,
              style: TextStyle(color: theme.textPrimary),
              cursorColor: theme.borderFocus,
              decoration: InputDecoration(
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Emoji',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emojiController,
              style: TextStyle(color: theme.textPrimary, fontSize: 16),
              cursorColor: theme.borderFocus,
              maxLength: 2,
              decoration: InputDecoration(
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Deskripsi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deskripsiController,
              style: TextStyle(color: theme.textPrimary),
              cursorColor: theme.borderFocus,
              maxLines: 3,
              decoration: InputDecoration(
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.bgElevated,
                      foregroundColor: theme.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: theme.border),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateKategori,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.btnPrimary,
                      foregroundColor: theme.btnLabel,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.btnLabel,
                            ),
                          )
                        : const Text('Simpan'),
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
