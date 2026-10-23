import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Satu baris notifikasi milik user (tabel `notifications`).
class AppNotification {
  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id: (m['id'] as num?)?.toInt() ?? 0,
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      type: (m['type'] as String?) ?? 'info',
      isRead: m['is_read'] == true,
      createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '')?.toLocal(),
    );
  }
}

/// Sumber tunggal notifikasi user.
///
/// - `start()`  → muat awal + polling tiap 15 detik (pengganti realtime).
/// - `onNew`    → stream notifikasi baru, dipakai untuk memunculkan pop-up.
/// - `unreadCount` → angka badge di ikon lonceng.
///
/// Realtime Supabase tidak dipakai supaya tetap jalan di Windows
/// (realtime butuh tabel masuk publication & koneksi websocket stabil).
class NotificationCenter extends ChangeNotifier {
  static const Duration _pollInterval = Duration(seconds: 15);
  static const int _pageSize = 60;

  final SupabaseClient _client = Supabase.instance.client;

  final List<AppNotification> _items = [];
  final Set<int> _knownIds = {};
  final StreamController<AppNotification> _newCtrl =
      StreamController<AppNotification>.broadcast();

  Timer? _timer;
  bool _started = false;
  bool _loading = false;
  String? _userId;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((e) => !e.isRead).length;
  bool get loading => _loading;
  Stream<AppNotification> get onNew => _newCtrl.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh(initial: true);
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Muat ulang daftar notifikasi user.
  /// `initial = true` → jangan picu pop-up untuk notifikasi lama.
  Future<void> refresh({bool initial = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // User berganti (logout → login akun lain) → reset state.
    if (_userId != null && _userId != user.id) {
      _items.clear();
      _knownIds.clear();
      _userId = user.id;
      initial = true;
    }
    _userId = user.id;

    if (_loading) return;
    _loading = true;
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final fresh = (data as List)
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromMap)
          .toList();

      final arrivals = <AppNotification>[];
      for (final n in fresh) {
        if (!_knownIds.contains(n.id)) {
          _knownIds.add(n.id);
          if (!initial) arrivals.add(n);
        }
      }

      _items
        ..clear()
        ..addAll(fresh);

      // Kirim yang paling lama dulu supaya urutan pop-up natural.
      if (arrivals.isNotEmpty) {
        for (final n in arrivals.reversed) {
          if (!n.isRead) _newCtrl.add(n);
        }
      }
    } catch (e) {
      debugPrint('[NotificationCenter] refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _patchLocal(id, isRead: true);
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('[NotificationCenter] markRead error: $e');
    }
  }

  Future<void> markAllRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      if (!n.isRead) {
        _items[i] = AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
        );
      }
    }
    notifyListeners();
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationCenter] markAllRead error: $e');
    }
  }

  Future<void> deleteOne(int id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _items.removeWhere((e) => e.id == id);
    _knownIds.remove(id);
    notifyListeners();
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('[NotificationCenter] deleteOne error: $e');
    }
  }

  Future<void> deleteAll() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _items.clear();
    _knownIds.clear();
    notifyListeners();
    try {
      await _client.from('notifications').delete().eq('user_id', user.id);
    } catch (e) {
      debugPrint('[NotificationCenter] deleteAll error: $e');
    }
  }

  void _patchLocal(int id, {required bool isRead}) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final n = _items[idx];
    _items[idx] = AppNotification(
      id: n.id,
      title: n.title,
      body: n.body,
      type: n.type,
      isRead: isRead,
      createdAt: n.createdAt,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _newCtrl.close();
    super.dispose();
  }
}

/// Kirim notifikasi ke daftar user (dipakai dari sisi admin).
///
/// Tabel `notifications` punya policy INSERT terbuka, jadi bisa ditulis
/// langsung dari client tanpa Edge Function.
Future<int> sendNotifications({
  required List<String> userIds,
  required String title,
  required String body,
  String type = 'info',
}) async {
  if (userIds.isEmpty) return 0;
  final rows = userIds
      .map((id) => {
            'user_id': id,
            'title': title,
            'body': body,
            'type': type,
          })
      .toList();

  try {
    await Supabase.instance.client.from('notifications').insert(rows);
  } catch (e) {
    debugPrint('[NotificationCenter] send error: $e');
    return 0;
  }

  // Push ke device (Android) lewat Edge Function — API key aman di server.
  // Kalau gagal, notifikasi in-app tetap masuk, jadi jangan dianggap error.
  try {
    await Supabase.instance.client.functions.invoke(
      'send-notification',
      body: {
        'title': title,
        'body': body,
        'targetUserIds': userIds,
        'type': type,
      },
    );
  } catch (e) {
    debugPrint('[NotificationCenter] push error: $e');
  }

  return rows.length;
}
