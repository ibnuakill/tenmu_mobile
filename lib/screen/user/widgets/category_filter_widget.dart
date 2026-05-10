import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/umkm_category.dart';

/// CategoryFilterWidget - Menampilkan chip kategori yang bisa di-toggle
/// User bisa select multiple categories untuk filter
class CategoryFilterWidget extends StatefulWidget {
  final Set<String> selectedCategories;
  final ValueChanged<Set<String>> onCategoriesChanged;

  const CategoryFilterWidget({
    Key? key,
    required this.selectedCategories,
    required this.onCategoriesChanged,
  }) : super(key: key);

  @override
  State<CategoryFilterWidget> createState() => _CategoryFilterWidgetState();
}

class _CategoryFilterWidgetState extends State<CategoryFilterWidget> {
  late Set<String> _localSelected;

  @override
  void initState() {
    super.initState();
    _localSelected = Set.from(widget.selectedCategories);
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_localSelected.contains(category)) {
        _localSelected.remove(category);
      } else {
        _localSelected.add(category);
      }
    });
    // Notify parent about changes
    widget.onCategoriesChanged(_localSelected);
  }

  void _clearAll() {
    setState(() {
      _localSelected.clear();
    });
    widget.onCategoriesChanged(_localSelected);
  }

  void _selectAll() {
    setState(() {
      _localSelected = Set.from(UmkmCategory.allCategories);
    });
    widget.onCategoriesChanged(_localSelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header dengan tombol "Clear All" dan "Select All"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _clearAll,
                      child: Text(
                        'Hapus',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.btnPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _selectAll,
                      child: Text(
                        'Semua',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.btnPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Category Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: UmkmCategory.allCategories.map((category) {
                final isSelected = _localSelected.contains(category);
                final emoji = UmkmCategory.getCategoryEmoji(category);

                return GestureDetector(
                  onTap: () => _toggleCategory(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.btnPrimary : theme.bgSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? theme.btnPrimary : theme.border,
                        width: isSelected ? 0 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? theme.btnLabel : theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
