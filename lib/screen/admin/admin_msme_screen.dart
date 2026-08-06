import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_image_helper.dart';
import '../owner/edit_place_screen.dart';

class AdminMsmeScreen extends StatefulWidget {
  const AdminMsmeScreen({super.key});

  @override
  State<AdminMsmeScreen> createState() => _AdminMsmeScreenState();
}

class _AdminMsmeScreenState extends State<AdminMsmeScreen> {
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _allPlaces = [];
  List<Map<String, dynamic>> _filteredPlaces = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | verified | pending | rejected

  static const _pageSize = 20;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _client
          .from('places')
          .select('*')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _allPlaces = (data as List).cast<Map<String, dynamic>>();
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(
          0,
          _filteredPlaces.length,
        );
      });
    }
  }

  void _applyFilters() {
    var list = _allPlaces;
    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name = (p['nama_tempat'] as String? ?? '').toLowerCase();
        final cat = (p['category'] as String? ?? '').toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }
    // Status filter
    if (_statusFilter != 'all') {
      list = list
          .where(
            (p) =>
                (p['verification_status'] as String? ?? 'pending') ==
                _statusFilter,
          )
          .toList();
    }
    setState(() {
      _filteredPlaces = list;
      _visibleCount = _pageSize;
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Text(
          'Manage MSME',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: theme.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : Column(
              children: [
                // ── SEARCH + ACTION BAR ──
                _searchBar(theme),
                const SizedBox(height: 12),
                // ── STATUS FILTER CHIPS ──
                _statusChips(theme),
                const SizedBox(height: 8),
                // ── DATA TABLE / LIST ──
                Expanded(child: _dataView(theme)),
              ],
            ),
    );
  }

  Widget _errorView() {
    final theme = Provider.of<ThemeProvider>(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: theme.textHint),
            const SizedBox(height: 12),
            Text(
              'Failed to load MSME data.',
              style: TextStyle(color: theme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadPlaces,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: theme.textHint, size: 20),
                hintText: 'Search MSMEs by name or category...',
                hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(fontSize: 14, color: theme.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list, size: 16, color: theme.btnPrimary),
                const SizedBox(width: 4),
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.btnPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Add MSME button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.btnPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: theme.btnLabel),
                const SizedBox(width: 4),
                Text(
                  'Add MSME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.btnLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChips(ThemeProvider theme) {
    final chips = [
      ('all', 'All', null),
      ('verified', 'Verified', const Color(0xFF10B981)),
      ('pending', 'Pending', const Color(0xFFF59E0B)),
      ('rejected', 'Rejected', const Color(0xFFBA1A1A)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: chips.map((c) {
          final isActive = _statusFilter == c.$1;
          return GestureDetector(
            onTap: () {
              _statusFilter = c.$1;
              _applyFilters();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? (c.$3 ?? theme.btnPrimary).withValues(alpha: 0.15)
                    : theme.bgElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                c.$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (c.$3 ?? theme.btnPrimary)
                      : theme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dataView(ThemeProvider theme) {
    if (_filteredPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: theme.textHint),
            const SizedBox(height: 12),
            Text(
              'No MSME data found.',
              style: TextStyle(color: theme.textSecondary),
            ),
          ],
        ),
      );
    }

    final displayList = _filteredPlaces.take(_visibleCount).toList();

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayList.length + 1, // +1 for load more
      itemBuilder: (context, index) {
        if (index >= displayList.length) {
          // Load more indicator
          if (_visibleCount >= _filteredPlaces.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _visibleCount = (_visibleCount + _pageSize).clamp(
                      0,
                      _filteredPlaces.length,
                    );
                  });
                },
                child: Text(
                  'Load More Data',
                  style: TextStyle(fontSize: 12, color: theme.btnPrimary),
                ),
              ),
            ),
          );
        }

        final place = displayList[index];
        final name = place['nama_tempat'] ?? 'Unknown';
        final category = place['category'] ?? '-';
        final status = place['verification_status'] ?? 'pending';
        final imageUrl = PoiImageHelper.primaryImageUrl(place);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatar(theme, name),
                          )
                        : _avatar(theme, name),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionBtn(
                    Icons.visibility_outlined,
                    'View',
                    theme.textSecondary,
                    theme,
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    Icons.edit_outlined,
                    'Edit',
                    theme.btnPrimary,
                    theme,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditPlaceScreen(place: place),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatar(ThemeProvider theme, String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.btnPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'verified':
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
        textColor = const Color(0xFF10B981);
        label = 'Verified';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        bgColor = const Color(0xFFBA1A1A).withValues(alpha: 0.1);
        textColor = const Color(0xFFBA1A1A);
        label = 'Rejected';
        icon = Icons.cancel;
        break;
      default:
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.1);
        textColor = const Color(0xFFF59E0B);
        label = 'Pending';
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    ThemeProvider theme, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.bgElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
