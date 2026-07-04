import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('places')
          .select('id, nama_tempat, verification_status, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _activities = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgSurface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: theme.textPrimary, size: 16),
          ),
        ),
        title: Text(
          'Recent Activity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: theme.textHint),
                      const SizedBox(height: 12),
                      Text('No recent activity', style: TextStyle(color: theme.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  separatorBuilder: (_, a) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final a = _activities[i];
                    final name = a['nama_tempat'] ?? 'Unknown';
                    final status = a['verification_status'] ?? 'pending';
                    final createdAt = a['created_at'] as String? ?? '';
                    final timeAgo = _timeAgo(createdAt);
                    return _activityItem(theme, name, status, timeAgo);
                  },
                ),
    );
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  Widget _activityItem(ThemeProvider theme, String name, String status, String time) {
    IconData icon;
    Color color;
    String desc;

    switch (status) {
      case 'verified':
        icon = Icons.add_business_outlined;
        color = const Color(0xFF10B981);
        desc = 'was verified';
        break;
      case 'rejected':
        icon = Icons.warning_amber_rounded;
        color = theme.snackError;
        desc = 'was rejected';
        break;
      default:
        icon = Icons.pending_outlined;
        color = const Color(0xFFF59E0B);
        desc = 'is pending review';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: theme.textSecondary, height: 1.3),
                    children: [
                      TextSpan(
                        text: name,
                        style: TextStyle(fontWeight: FontWeight.w600, color: theme.textPrimary),
                      ),
                      TextSpan(text: ' $desc'),
                    ],
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(fontSize: 11, color: theme.textHint)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
