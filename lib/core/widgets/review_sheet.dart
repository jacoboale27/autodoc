import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/models/review_model.dart';

/// Muestra un bottom sheet para calificar un taller/mecánico.
Future<bool?> showReviewBottomSheet(
  BuildContext context, {
  required String tallerId,
  required String tallerNombre,
  String? idServicio,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ReviewSheetContent(
      tallerId: tallerId,
      tallerNombre: tallerNombre,
      idServicio: idServicio,
    ),
  );
}

class _ReviewSheetContent extends StatefulWidget {
  final String tallerId;
  final String tallerNombre;
  final String? idServicio;

  const _ReviewSheetContent({
    required this.tallerId,
    required this.tallerNombre,
    this.idServicio,
  });

  @override
  State<_ReviewSheetContent> createState() => _ReviewSheetContentState();
}

class _ReviewSheetContentState extends State<_ReviewSheetContent> {
  final _reviewService = ReviewService();
  final _comentarioController = TextEditingController();
  int _estrellas = 5;
  bool _isSubmitting = false;
  bool _checking = true;

  ReviewModel? _existingReview;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final userId = context.read<UserSessionProvider>().userData?.idUsuario;
    if (userId == null) {
      setState(() => _checking = false);
      return;
    }
    final existing = await _reviewService.getUserReviewForTaller(userId, widget.tallerId);
    if (mounted) {
      setState(() {
        _existingReview = existing;
        if (existing != null) {
          _estrellas = existing.estrellas;
          _comentarioController.text = existing.comentario ?? '';
        }
        _checking = false;
      });
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<UserSessionProvider>();
    final userId = auth.userData?.idUsuario;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      if (_existingReview != null) {
        await _reviewService.updateReview(
          reviewId: _existingReview!.idResenia,
          tallerId: widget.tallerId,
          estrellas: _estrellas,
          comentario: _comentarioController.text,
        );
      } else {
        await _reviewService.submitReview(
          userId: userId,
          tallerId: widget.tallerId,
          estrellas: _estrellas,
          comentario: _comentarioController.text,
          idServicio: widget.idServicio,
        );
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Gracias por tu reseña!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Calificar taller',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.tallerNombre,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (_checking)
            const Center(child: CircularProgressIndicator())
          else ...[
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => _estrellas = star),
                    icon: Icon(
                      star <= _estrellas ? Icons.star : Icons.star_border,
                      color: colors.warning,
                      size: 36,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comentarioController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Cuéntanos tu experiencia...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: _isSubmitting ? 'Guardando...' : (_existingReview != null ? 'Actualizar reseña' : 'Publicar reseña'),
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
