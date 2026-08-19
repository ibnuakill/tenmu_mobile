import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';
import '../../widgets/category_filter_widget.dart';
import '../../widgets/sort_filter_widget.dart';

/// Modal sheet "Cari & Filter" yang dipakai home_screen.
/// State lokal (query, kategori, sort) → di-push ke parent via callback.
class HomeFilterSheet extends StatefulWidget {
  final ThemeProvider theme;
  final Color accent;
  final String initialQuery;
  final Set<String> initialCategories;
  final SortOption initialSort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Set<String>> onCategoriesChanged;
  final ValueChanged<SortOption> onSortChanged;
  final VoidCallback onReset;

  const HomeFilterSheet({
    super.key,
    required this.theme,
    required this.accent,
    required this.initialQuery,
    required this.initialCategories,
    required this.initialSort,
    required this.onQueryChanged,
    required this.onCategoriesChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialQuery,
    required Set<String> initialCategories,
    required SortOption initialSort,
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
          initialCategories: initialCategories,
          initialSort: initialSort,
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
  late Set<String> _cats;
  late SortOption _sort;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _cats = Set.from(widget.initialCategories);
    _sort = widget.initialSort;
  }

  bool get _isDirty =>
      _query.isNotEmpty || _cats.isNotEmpty || _sort != SortOption.terbaru;

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
                            _cats = {};
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
                    CategoryFilterWidget(
                      selectedCategories: _cats,
                      onCategoriesChanged: (s) {
                        setState(() => _cats = s);
                        widget.onCategoriesChanged(s);
                      },
                    ),
                    const SizedBox(height: 20),
                    SortFilterWidget(
                      selectedSort: _sort,
                      onSortChanged: (s) {
                        setState(() => _sort = s);
                        widget.onSortChanged(s);
                      },
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
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _ctrl.text.isNotEmpty
                  ? widget.accent
                  : widget.theme.textSecondary,
              size: 20,
            ),
            suffixIcon: _ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: widget.onClear,
                    child: Icon(
                      Icons.close_rounded,
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
