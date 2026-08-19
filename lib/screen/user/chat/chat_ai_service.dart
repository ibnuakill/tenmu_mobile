import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/places_provider.dart';
import 'chat_models.dart';

/// Logika AI chatbot: Edge Function Gemini (server-side) + fallback
/// pencarian lokal + riwayat chat (SharedPreferences). Tidak ada widget.
class ChatAIService {
  static const int _maxContextMessages = 10;

  /// Bersihkan markdown Gemini (**tebal**, *miring*, `kode`) → teks polos.
  static String cleanMarkdown(String text) {
    var t = text;
    t = t.replaceAll(RegExp(r'\*\*(.+?)\*\*', dotAll: true), r'$1');
    t = t.replaceAll(RegExp(r'\*(.+?)\*', dotAll: true), r'$1');
    t = t.replaceAll(RegExp(r'`(.+?)`', dotAll: true), r'$1');
    // bullet markdown di awal baris → bullet rapi
    t = t.replaceAll(RegExp(r'^[*•]\s', multiLine: true), '• ');
    return t;
  }

  /// Cek ringan apakah fungsi AI tersedia (tanpa membebani token Gemini).
  static Future<bool> ping() async {
    try {
      await Supabase.instance.client.functions.invoke('chat-bot', body: {
        'message': 'ping',
      });
      return true;
    } catch (_) {
      debugPrint('chat-bot ping failed — pakai fallback lokal');
      return false;
    }
  }

  /// Panggil Edge Function 'chat-bot'. Throws bila gagal (5xx/network);
  /// caller akan fallback ke pencarian lokal.
  static Future<({String reply, List<Map<String, dynamic>> mentioned})>
      callEdgeAi(String userText, List<ChatMessage> messages) async {
    final preview = messages.length > _maxContextMessages
        ? messages.sublist(messages.length - _maxContextMessages)
        : messages;
    final res = await Supabase.instance.client.functions.invoke(
      'chat-bot',
      body: {
        'message': userText,
        'history': preview
            .map((m) => {
                  'role': m.isUser ? 'user' : 'model',
                  'parts': [
                    {'text': m.text},
                  ],
                })
            .toList(),
      },
    );
    if (res.status >= 400) throw Exception('AI tidak tersedia (${res.status})');
    final data = (res.data as Map?) ?? const {};
    final reply = (data['reply'] as String?) ?? '';
    final mentioned = (data['mentioned'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    return (reply: reply, mentioned: mentioned);
  }

  // ── Riwayat chat: berbasis SESI (bisa dilihat/dibuka lagi) ──

  static const String _sessionsKey = 'chat_sessions_v1';
  static const String _legacyHistoryKey = 'chat_history_v1';
  static const int _maxSessions = 20;

  /// Muat semua sesi chat (terbaru di depan).
  static Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrasi satu kali dari format lama (satu percakapan) → 1 sesi.
    final legacy = prefs.getString(_legacyHistoryKey);
    if (legacy != null) {
      await prefs.remove(_legacyHistoryKey);
      final msgs = _decodeMessages(legacy);
      if (msgs.isNotEmpty) {
        final session = ChatSession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          updatedAt: msgs.last.time,
          messages: msgs,
        );
        await _persist(prefs, [session]);
        return [session];
      }
    }

    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list
          .map((e) => ChatSession(
                id: (e['id'] as String?) ?? '',
                updatedAt:
                    DateTime.tryParse((e['updatedAt'] as String?) ?? '') ??
                    DateTime.now(),
                messages: _decodeMessages(jsonEncode(e['messages'] ?? [])),
              ))
          .where((s) => s.id.isNotEmpty && s.messages.isNotEmpty)
          .toList();
    } catch (_) {
      return []; // data korup → mulai kosong
    }
  }

  /// Simpan satu sesi (upsert; terbaru ditaruh di depan).
  static Future<void> saveSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final keep = sessions.length > _maxSessions
        ? sessions.sublist(0, _maxSessions)
        : sessions;
    await _persist(prefs, keep);
  }

  /// Hapus satu sesi dari riwayat.
  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == id);
    await _persist(prefs, sessions);
  }

  static Future<void> _persist(
    SharedPreferences prefs,
    List<ChatSession> sessions,
  ) {
    final raw = jsonEncode(
      sessions
          .map((s) => {
                'id': s.id,
                'updatedAt': s.updatedAt.toIso8601String(),
                'messages': s.messages
                    .map((m) => {
                          'text': m.text,
                          'isUser': m.isUser,
                          'time': m.time.toIso8601String(),
                        })
                    .toList(),
              })
          .toList(),
    );
    return prefs.setString(_sessionsKey, raw);
  }

  static List<ChatMessage> _decodeMessages(String jsonStr) {
    try {
      final list = (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>();
      return list
          .map((e) => ChatMessage(
                text: (e['text'] as String?) ?? '',
                isUser: (e['isUser'] as bool?) ?? false,
                time:
                    DateTime.tryParse((e['time'] as String?) ?? '') ??
                    DateTime.now(),
              ))
          .where((m) => m.text.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Fallback lokal (tanpa API) ───────────────────────────

  /// Kata kunci yang menandakan pertanyaan seputar tempat.
  static const List<String> _placeKeywords = [
    'cafe', 'kopi', 'wisata', 'kuliner', 'makan', 'restoran', 'hotel',
    'penginapan', 'dekat', 'tempat', 'rekomendasi', 'oleh-oleh', 'umkm',
    'nongkrong', 'buka', 'tutup', 'murah', 'favorit', 'terdekat', 'rute',
    'fasilitas', 'harga', 'alamat', 'review', 'bagus', 'enak', 'seru',
  ];

  /// Fallback: pencarian kata kunci lokal (tanpa API).
  /// Hanya relevan untuk pertanyaan seputar tempat; pertanyaan umum
  /// dijawab dengan pesan jujur bahwa AI sedang tidak tersedia.
  static ({String reply, List<Map<String, dynamic>> results}) localSearch(
    BuildContext context,
    String userText,
  ) {
    final provider = context.read<PlacesProvider>();
    if (provider.placesList.isEmpty) {
      provider.fetchPlaces(); // pemicu async, hasil bisa langsung tampil
    }

    final query = userText.toLowerCase();
    final isPlaceQuery =
        _placeKeywords.any((k) => query.contains(k)) || query.contains('di ');

    if (!isPlaceQuery) {
      return (
        reply:
            'AI-ku lagi offline, coba lagi sebentar ya 🙏\n'
            'Sementara, aku tetap bisa bantu cari tempat — coba tanya '
            '"cafe dekat sini" atau "rekomendasi wisata"!',
        results: const [],
      );
    }

    final results = provider.placesList
        .where((p) {
          final nama = (p['nama_tempat']?.toString() ?? '').toLowerCase();
          final desc = (p['deskripsi']?.toString() ?? '').toLowerCase();
          final cat = (p['category']?.toString() ?? '').toLowerCase();
          final fas = (p['fasilitas']?.toString() ?? '').toLowerCase();
          return nama.contains(query) ||
              desc.contains(query) ||
              cat.contains(query) ||
              fas.contains(query);
        })
        .take(5)
        .toList();

    String reply;
    if (results.isEmpty) {
      reply =
          'Maaf, ga nemu tempat yang cocok dengan "$userText". Coba keyword lain ya!';
    } else {
      final sb = StringBuffer('Ketemu ${results.length} tempat:\n');
      for (var i = 0; i < results.length; i++) {
        sb.writeln('${i + 1}. ${results[i]['nama_tempat']}');
      }
      sb.write('\nTap pilihan di bawah buat lihat detail!');
      reply = sb.toString();
    }
    return (reply: reply, results: results);
  }
}
