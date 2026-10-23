import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notification_center.dart';
import '../dashboard/widgets/admin_design.dart';

/// Admin → Notifikasi.
///
/// Kirim pesan ke pengguna TenMu. Setiap pesan masuk ke tabel `notifications`
/// milik masing-masing user sehingga muncul di ikon lonceng + pop-up di app.
class AdminNotifikasiScreen extends StatefulWidget {
  const AdminNotifikasiScreen({super.key});

  @override
  State<AdminNotifikasiScreen> createState() => _AdminNotifikasiScreenState();
}

class _SentItem {
  final String title;
  final String type;
  final int recipients;
  final DateTime at;

  const _SentItem({
    required this.title,
    required this.type,
    required this.recipients,
    required this.at,
  });
}

class _AdminNotifikasiScreenState extends State<AdminNotifikasiScreen> {
  final _client = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _type = 'info';
  String _target = 'all';
  bool _loadingRecipients = true;
  bool _sending = false;

  List<String> _userIds = [];
  List<String> _ownerIds = [];
  List<_SentItem> _sent = [];

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    setState(() => _loadingRecipients = true);
    try {
      final data = await _client
          .from('profiles')
          .select('id, role, status')
          .inFilter('role', ['user', 'owner']);

      final users = <String>[];
      final owners = <String>[];
      for (final row in (data as List).cast<Map<String, dynamic>>()) {
        if ((row['status'] as String?) == 'suspended') continue;
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        if (row['role'] == 'owner') {
          owners.add(id);
        } else {
          users.add(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _userIds = users;
        _ownerIds = owners;
        _loadingRecipients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRecipients = false);
      _snack('Gagal memuat daftar penerima: $e', error: true);
    }
  }

  List<String> get _recipients {
    switch (_target) {
      case 'user':
        return _userIds;
      case 'owner':
        return _ownerIds;
      default:
        return [..._userIds, ..._ownerIds];
    }
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty) {
      _snack('Judul notifikasi belum diisi.', error: true);
      return;
    }
    if (body.isEmpty) {
      _snack('Pesan notifikasi belum diisi.', error: true);
      return;
    }
    final ids = _recipients;
    if (ids.isEmpty) {
      _snack('Tidak ada penerima untuk target ini.', error: true);
      return;
    }

    setState(() => _sending = true);
    final sent = await sendNotifications(
      userIds: ids,
      title: title,
      body: body,
      type: _type,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (sent == 0) {
      _snack('Gagal mengirim notifikasi. Coba lagi.', error: true);
      return;
    }

    setState(() {
      _sent = [
        _SentItem(
          title: title,
          type: _type,
          recipients: sent,
          at: DateTime.now(),
        ),
        ..._sent,
      ];
      _titleCtrl.clear();
      _bodyCtrl.clear();
    });
    _snack('Notifikasi terkirim ke $sent pengguna.');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? kAccentRed : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kPageBg,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final wide = c.maxWidth >= 980;
          final compose = _buildComposeCard();
          final history = _buildHistoryCard();

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 28 : 16,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildStats(),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: compose),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: history),
                    ],
                  )
                else ...[
                  compose,
                  const SizedBox(height: 18),
                  history,
                ],
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.notifications_active_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifikasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Kirim pesan yang langsung masuk ke ikon notifikasi pengguna',
                style: TextStyle(fontSize: 12.5, color: kTextSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final total = _userIds.length + _ownerIds.length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard('Pengguna', _loadingRecipients ? '—' : '${_userIds.length}'),
        _statCard('Owner UMKM', _loadingRecipients ? '—' : '${_ownerIds.length}'),
        _statCard('Total Penerima', _loadingRecipients ? '—' : '$total'),
        _statCard('Terkirim (sesi)', '${_sent.length}'),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tulis Pesan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _label('Judul'),
          const SizedBox(height: 6),
          _input(_titleCtrl, 'Contoh: Promo akhir bulan'),
          const SizedBox(height: 14),
          _label('Pesan'),
          const SizedBox(height: 6),
          _input(_bodyCtrl, 'Tulis isi notifikasi...', maxLines: 4),
          const SizedBox(height: 14),
          _label('Tipe'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeChip('info', 'Info'),
              _typeChip('promo', 'Promo'),
              _typeChip('warning', 'Peringatan'),
              _typeChip('success', 'Sukses'),
            ],
          ),
          const SizedBox(height: 14),
          _label('Penerima'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kPageBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: kBorderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _target,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Semua akun')),
                  DropdownMenuItem(
                    value: 'user',
                    child: Text('Pengguna saja'),
                  ),
                  DropdownMenuItem(
                    value: 'owner',
                    child: Text('Owner UMKM saja'),
                  ),
                ],
                onChanged: (v) => setState(() => _target = v ?? 'all'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildPreview(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 17),
              label: Text(
                _sending
                    ? 'Mengirim...'
                    : 'Kirim ke ${_loadingRecipients ? '...' : _recipients.length} penerima',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kPageBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: const Center(
          child: Text(
            'Preview muncul di sini',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
      );
    }

    final color = _typeColor(_type);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon(_type), size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Judul notifikasi' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terkirim Sesi Ini',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Riwayat pengiriman selama halaman ini terbuka.',
            style: TextStyle(fontSize: 11.5, color: kTextSecondary),
          ),
          const SizedBox(height: 14),
          if (_sent.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                color: kPageBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 26,
                    color: kTextMuted,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Belum ada notifikasi terkirim',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted),
                  ),
                ],
              ),
            )
          else
            ..._sent.map((s) {
              final color = _typeColor(s.type);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPageBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${s.recipients} penerima · ${_timeStr(s.at)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: kTextSecondary,
          letterSpacing: 0.2,
        ),
      );

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13, color: kTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: kTextMuted),
        filled: true,
        fillColor: kPageBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: kPrimary, width: 1.4),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final active = _type == value;
    final color = _typeColor(value);
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : kPageBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? color : kBorderColor,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _typeIcon(value),
              size: 13,
              color: active ? color : kTextSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'success':
        return kAccentGreen;
      case 'warning':
        return kAccentAmber;
      case 'promo':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF1A7A6E);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'promo':
        return Icons.campaign_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _timeStr(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}
