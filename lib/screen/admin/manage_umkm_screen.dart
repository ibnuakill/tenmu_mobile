import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';
import 'edit_umkm_screen.dart';

class ManageUmkmScreen extends StatefulWidget {
  const ManageUmkmScreen({super.key});

  @override
  State<ManageUmkmScreen> createState() => _ManageUmkmScreenState();
}

class _ManageUmkmScreenState extends State<ManageUmkmScreen> {
  final _umkmStream = Supabase.instance.client
      .from('umkm')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Future<void> _hapusData(int id, String nama) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          'Hapus Data?',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Kamu yakin ingin menghapus "$nama"? Tindakan ini tidak bisa dibatalkan.',
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
        await Supabase.instance.client.from('umkm').delete().eq('id', id);
        if (mounted) {
          final theme = Provider.of<ThemeProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Data berhasil dihapus.',
                style: TextStyle(color: theme.textPrimary),
              ),
              backgroundColor: theme.snackSuccess,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.snackSuccessBorder),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final theme = Provider.of<ThemeProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menghapus: $e',
                style: TextStyle(color: theme.textPrimary),
              ),
              backgroundColor: theme.snackError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.snackErrorBorder),
              ),
            ),
          );
        }
      }
    }
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
          'Kelola Data UMKM',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _umkmStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.iconColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: theme.textSecondary),
              ),
            );
          }

          final umkmList = snapshot.data ?? [];

          if (umkmList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: theme.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada data.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: umkmList.length,
            itemBuilder: (context, index) {
              final umkm = umkmList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: umkm['gambar_url'] != null
                        ? Image.network(
                            umkm['gambar_url'],
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 58,
                              height: 58,
                              color: theme.bgElevated,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: theme.textHint,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            width: 58,
                            height: 58,
                            color: theme.bgElevated,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: theme.iconColor,
                              size: 26,
                            ),
                          ),
                  ),
                  title: Text(
                    umkm['nama_tempat'] ?? 'Tanpa Nama',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      umkm['alamat'] ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconBtn(
                        icon: Icons.edit_outlined,
                        color: theme.borderFocus,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditUmkmScreen(umkm: umkm),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _iconBtn(
                        icon: Icons.delete_outline,
                        color: const Color(0xFF8B2020),
                        onTap: () =>
                            _hapusData(umkm['id'], umkm['nama_tempat']),
                      ),
                    ],
                  ),
                ),
              );
            },
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
