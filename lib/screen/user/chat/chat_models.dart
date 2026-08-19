/// Config & model untuk AI chatbot.
class ChatBotConfig {
  static const String botName = 'TenMu AI';
  static const String botAvatar = '🤖';
  static const String userAvatar = '👤';
}

/// Satu pesan dalam percakapan chat.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, DateTime? time})
    : time = time ?? DateTime.now();
}

/// Satu sesi percakapan chat (riwayat yang bisa dilihat user).
class ChatSession {
  final String id;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.updatedAt,
    required this.messages,
  });

  /// Teks singkat sebagai judul sesi: pesan user pertama yang ada.
  String get preview {
    for (final m in messages) {
      if (m.isUser) return m.text;
    }
    return messages.isEmpty ? '(kosong)' : messages.first.text;
  }

  String get timeLabel {
    final t = updatedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}
