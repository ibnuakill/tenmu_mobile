import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme_provider.dart';

/// Bottom sheet input review baru / edit review yang sudah ada.
class ReviewInputSheet extends StatefulWidget {
  final int umkmId;
  final Map<String, dynamic>? existingReview;
  final bool isEdit;
  final VoidCallback onSubmitted;

  const ReviewInputSheet({
    super.key,
    required this.umkmId,
    required this.existingReview,
    required this.isEdit,
    required this.onSubmitted,
  });

  @override
  State<ReviewInputSheet> createState() => _ReviewInputSheetState();
}

class _ReviewInputSheetState extends State<ReviewInputSheet> {
  final _client = Supabase.instance.client;
  final _controller = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.existingReview != null) {
      _selectedRating = widget.existingReview!['rating'] as int;
      _controller.text = widget.existingReview!['komentar'] ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih bintang terlebih dahulu.'),
          backgroundColor: theme.snackError,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final userId = _client.auth.currentUser!.id;

    try {
      if (widget.isEdit && widget.existingReview != null) {
        await _client
            .from('reviews')
            .update({
              'rating': _selectedRating,
              'komentar': _controller.text.trim().isEmpty
                  ? null
                  : _controller.text.trim(),
            })
            .eq('id', widget.existingReview!['id']);
      } else {
        await _client.from('reviews').upsert({
          'umkm_id': widget.umkmId,
          'user_id': userId,
          'rating': _selectedRating,
          'komentar': _controller.text.trim().isEmpty
              ? null
              : _controller.text.trim(),
        }, onConflict: 'umkm_id, user_id');
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'Ulasan berhasil diperbarui.'
                  : 'Ulasan berhasil dikirim.',
              style: TextStyle(color: theme.textPrimary),
            ),
            backgroundColor: theme.snackSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.snackSuccessBorder),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim ulasan: $e',
              style: TextStyle(color: theme.textPrimary),
            ),
            backgroundColor: theme.snackError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.snackErrorBorder),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.isEdit ? 'Edit Ulasan' : 'Beri Ulasan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bagaimana pengalamanmu di tempat ini?',
            style: TextStyle(fontSize: 13, color: theme.textSecondary),
          ),
          const SizedBox(height: 20),

          // Star picker
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final starValue = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starValue <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: starValue <= _selectedRating
                          ? const Color(0xFFFFB800)
                          : theme.textHint,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _selectedRating == 0
                  ? 'Ketuk bintang untuk memberi nilai'
                  : _ratingLabel(_selectedRating),
              style: TextStyle(
                fontSize: 13,
                color: _selectedRating > 0
                    ? const Color(0xFFFFB800)
                    : theme.textHint,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Komentar
          Container(
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 300,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              cursorColor: theme.borderFocus,
              decoration: InputDecoration(
                hintText: 'Tulis komentarmu (opsional)...',
                hintStyle: TextStyle(color: theme.textHint, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: TextStyle(color: theme.textHint, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.btnLabel,
                      ),
                    )
                  : Text(
                      widget.isEdit ? 'Perbarui Ulasan' : 'Kirim Ulasan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.btnLabel,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Buruk';
      case 2:
        return 'Kurang Baik';
      case 3:
        return 'Cukup';
      case 4:
        return 'Bagus';
      case 5:
        return 'Luar Biasa!';
      default:
        return '';
    }
  }
}