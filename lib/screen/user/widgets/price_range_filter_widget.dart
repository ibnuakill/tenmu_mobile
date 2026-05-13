import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';

/// PriceRangeFilterWidget - Filter UMKM berdasarkan rentang harga
/// User bisa drag slider untuk set min dan max price
class PriceRangeFilterWidget extends StatefulWidget {
  final RangeValues initialRange;
  final double minPrice;
  final double maxPrice;
  final ValueChanged<RangeValues> onRangeChanged;

  const PriceRangeFilterWidget({
    Key? key,
    required this.initialRange,
    this.minPrice = 0,
    this.maxPrice = 1000000,
    required this.onRangeChanged,
  }) : super(key: key);

  @override
  State<PriceRangeFilterWidget> createState() => _PriceRangeFilterWidgetState();
}

class _PriceRangeFilterWidgetState extends State<PriceRangeFilterWidget> {
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange;
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  void _resetRange() {
    setState(() {
      _currentRange = RangeValues(widget.minPrice, widget.maxPrice);
    });
    widget.onRangeChanged(_currentRange);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header dengan tombol Reset ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rentang Harga',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _resetRange,
                child: Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.btnPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Display current range ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Min',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(_currentRange.start),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 40, color: theme.divider),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Max',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(_currentRange.end),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Range Slider ───────────────────────────────────────────────
          RangeSlider(
            values: _currentRange,
            min: widget.minPrice,
            max: widget.maxPrice,
            divisions: 20,
            onChanged: (RangeValues values) {
              setState(() {
                _currentRange = values;
              });
            },
            onChangeEnd: (RangeValues values) {
              widget.onRangeChanged(values);
            },
            activeColor: theme.btnPrimary,
            inactiveColor: theme.border,
            labels: RangeLabels(
              _formatPrice(_currentRange.start),
              _formatPrice(_currentRange.end),
            ),
          ),

          // ── Min/Max text info ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatPrice(widget.minPrice),
                  style: TextStyle(fontSize: 11, color: theme.textSecondary),
                ),
                Text(
                  _formatPrice(widget.maxPrice),
                  style: TextStyle(fontSize: 11, color: theme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
