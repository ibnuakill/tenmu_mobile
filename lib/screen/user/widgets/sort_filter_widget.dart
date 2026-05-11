import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';

enum SortOption { terbaru, terdekat, rating }

class SortFilterWidget extends StatelessWidget {
  final SortOption selectedSort;
  final ValueChanged<SortOption> onSortChanged;

  const SortFilterWidget({
    super.key,
    required this.selectedSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Urutkan Berdasarkan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildSortChip(theme, SortOption.terbaru, 'Terbaru', Icons.access_time),
              const SizedBox(width: 8),
              _buildSortChip(theme, SortOption.terdekat, 'Terdekat (GPS)', Icons.location_on),
              const SizedBox(width: 8),
              _buildSortChip(theme, SortOption.rating, 'Rating Tertinggi', Icons.star),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(ThemeProvider theme, SortOption option, String label, IconData icon) {
    final isSelected = selectedSort == option;
    return GestureDetector(
      onTap: () => onSortChanged(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.btnPrimary : theme.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.btnPrimary : theme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? theme.btnLabel : theme.iconColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? theme.btnLabel : theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
