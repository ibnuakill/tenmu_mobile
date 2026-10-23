import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';
import '../../widgets/sort_filter_widget.dart';
import '../../../../core/lucide_icons.dart';
import '../../../../core/poi_category.dart';

/// Modal sheet "Cari & Filter" yang dipakai home_screen.
/// State lokal (query, kategori, sort) → di-push ke parent via callback.
class HomeFilterSheet extends StatefulWidget {
  final ThemeProvider theme;
  final Color accent;
  final String initialQuery;
  final SortOption initialSort;
  final Set<String> initialCategories;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Set<String>> onCategoriesChanged;
  final ValueChanged<SortOption> onSortChanged;
  final VoidCallback onReset;

  const HomeFilterSheet({
    super.key,
    required this.theme,
    required this.accent,
    required this.initialQuery,
    required this.initialSort,
    this.initialCategories = const {},
    required this.onQueryChanged,
    required this.onCategoriesChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialQuery,
    required SortOption initialSort,
    Set<String> initialCategories = const {},
    required ValueChanged<String> onQueryChanged,
    required ValueChanged<Set<String>> onCategoriesChanged,
    required ValueChanged<SortOption> onSortChanged,
    required VoidCallback onReset,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final accent = theme.btnPrimary;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return HomeFilterSheet(
          theme: theme,
          accent: accent,
          initialQuery: initialQuery,
          initialSort: initialSort,
          initialCategories: initialCategories,
          onQueryChanged: onQueryChanged,
          onCategoriesChanged: onCategoriesChanged,
          onSortChanged: onSortChanged,
          onReset: onReset,
        );
      },
    );
  }

  @override
  State<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<HomeFilterSheet> {
  late String _query;
  late SortOption _sort;
  late Set<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _sort = widget.initialSort;
    _selectedCategories = Set.from(widget.initialCategories);
  }

  bool get _isDirty =>
      _query.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _sort != SortOption.terbaru;

  void _toggleCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        // Pilih satu kategori saja (single select)
        _selectedCategories = {cat};
      }
      widget.onCategoriesChanged(_selectedCategories);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: widget.theme.bgBase,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.theme.borderFocus,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Cari & Filter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.theme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_isDirty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _query = '';
                            _sort = SortOption.terbaru;
                          });
                          widget.onReset();
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SearchField(
                theme: widget.theme,
                accent: widget.accent,
                initial: _query,
                onChanged: (v) {
                  setState(() => _query = v);
                  widget.onQueryChanged(v);
                },
                onClear: () {
                  setState(() => _query = '');
                  widget.onQueryChanged('');
                },
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: widget.theme.border, height: 1),
                    ),
                    SortFilterWidget(
                      selectedSort: _sort,
                      onSortChanged: (s) {
                        setState(() => _sort = s);
                        widget.onSortChanged(s);
                      },
                    ),
                    const SizedBox(height: 16),
                    _CategorySection(
                      theme: widget.theme,
                      accent: widget.accent,
                      selectedCategories: _selectedCategories,
                      onToggleCategory: _toggleCategory,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  final ThemeProvider theme;
  final Color accent;
  final String initial;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.theme,
    required this.accent,
    required this.initial,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial)
      ..selection = TextSelection.collapsed(offset: widget.initial.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: widget.theme.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _ctrl.text.isNotEmpty ? widget.accent : widget.theme.border,
            width: _ctrl.text.isNotEmpty ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v.toLowerCase());
          },
          style: TextStyle(color: widget.theme.textPrimary, fontSize: 14),
          cursorColor: widget.accent,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'Cari tempat wisata, kuliner...',
            hintStyle: TextStyle(color: widget.theme.textHint, fontSize: 13),
            prefixIcon: LucideIcon('search',
              color: _ctrl.text.isNotEmpty
                  ? widget.accent
                  : widget.theme.textSecondary,
              size: 20,
            ),
            suffixIcon: _ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: widget.onClear,
                    child: LucideIcon('x',
                      color: widget.theme.textSecondary,
                      size: 18,
                    ),
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
    );
  }
}

/// Section kategori: daftar 5 sektor (single-select, tanpa sub-kategori).
class _CategorySection extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final Set<String> selectedCategories;
  final ValueChanged<String> onToggleCategory;

  const _CategorySection({
    required this.theme,
    required this.accent,
    required this.selectedCategories,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Kategori',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textPrimary,
            ),
          ),
        ),
        ...PoiCategory.allCategories.map((cat) {
          final isSelected = selectedCategories.contains(cat);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onToggleCategory(cat),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.10)
                      : theme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? accent : theme.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PoiCategory.getCategoryIcon(cat),
                      size: 20,
                      color: isSelected ? accent : theme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? accent : theme.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check, size: 18, color: accent),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
