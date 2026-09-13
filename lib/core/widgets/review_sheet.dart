import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

/// Sustituye al `ImagePicker()` real. Solo lo usan los tests: no hay forma de
/// atravesar el canal de plataforma de `image_picker` en un widget test, así
/// que la selección se saca a un parámetro, igual que
/// `SelectorDeArchivo` en la pantalla de verificación del taller.
typedef SelectorDeFotoResenia = Future<XFile?> Function();

/// Muestra un bottom sheet para calificar un taller/mecánico.
///
/// Solo se puede reseñar un [idServicio] específico ya finalizado: cada
/// servicio admite una única reseña por usuario.
Future<bool?> showReviewBottomSheet(
  BuildContext context, {
  required String tallerId,
  required String tallerNombre,
  required String idServicio,
  ReviewService? reviewService,
  SelectorDeFotoResenia? selectorDeFoto,
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
      reviewService: reviewService,
      selectorDeFoto: selectorDeFoto,
    ),
  );
}

class _ReviewSheetContent extends StatefulWidget {
  final String tallerId;
  final String tallerNombre;
  final String idServicio;
  final ReviewService? reviewService;
  final SelectorDeFotoResenia? selectorDeFoto;

  const _ReviewSheetContent({
    required this.tallerId,
    required this.tallerNombre,
    required this.idServicio,
    this.reviewService,
    this.selectorDeFoto,
  });

  @override
  State<_ReviewSheetContent> createState() => _ReviewSheetContentState();
}

class _ReviewSheetContentState extends State<_ReviewSheetContent> {
  late final ReviewService _reviewService =
      widget.reviewService ?? ReviewService();
  final _comentarioController = TextEditingController();
  int _estrellas = 5;
  bool _isSubmitting = false;
  bool _checking = true;
  bool _canEdit = true;

  /// Fotos que ya están publicadas y el usuario decide mantener. Quitar una de
  /// aquí es lo que le pide al servicio borrarla de Storage.
  final List<String> _fotosPublicadas = [];

  /// Fotos elegidas en esta sesión y aún no subidas.
  final List<XFile> _fotosSeleccionadas = [];

  int get _totalFotos => _fotosPublicadas.length + _fotosSeleccionadas.length;

  ReviewModel? _existingReview;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final userId = context.read<UserProfileProvider>().userData?.idUsuario;
    if (userId == null) {
      setState(() => _checking = false);
      return;
    }
    try {
      final existing = await _reviewService.getUserReviewForService(
        userId,
        widget.idServicio,
      );
      if (mounted) {
        setState(() {
          _existingReview = existing;
          if (existing != null) {
            _estrellas = existing.estrellas;
            _comentarioController.text = existing.comentario ?? '';
            _fotosPublicadas
              ..clear()
              ..addAll(existing.fotos);
            if (DateTime.now().difference(existing.fechaResenia).inDays > 7) {
              _canEdit = false;
            }
          }
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checking = false);
        UiUtils.showErrorSnackbar(
          context,
          mensajeDeReglaDeNegocio(e, accion: 'No se pudo verificar tu reseña'),
        );
      }
    }
  }

  Future<void> _pickFoto() async {
    if (_totalFotos >= ReviewService.maxFotos) return;
    final seleccionar =
        widget.selectorDeFoto ??
        () => ImagePicker().pickImage(source: ImageSource.gallery);
    final XFile? foto = await seleccionar();
    if (foto != null && mounted) {
      setState(() => _fotosSeleccionadas.add(foto));
    }
  }

  void _removeFoto(int index) {
    setState(() => _fotosSeleccionadas.removeAt(index));
  }

  void _removeFotoPublicada(String url) {
    setState(() => _fotosPublicadas.remove(url));
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<UserProfileProvider>();
    final userId = auth.userData?.idUsuario;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      if (_existingReview != null) {
        // Las fotos viajan explicitamente: `fotosConservadas` es la lista
        // completa que debe quedar de las ya publicadas, asi que lo que el
        // usuario quito aqui es lo que el servicio borrara de Storage.
        await _reviewService.updateReview(
          reviewId: _existingReview!.idResenia,
          tallerId: widget.tallerId,
          estrellas: _estrellas,
          comentario: _comentarioController.text,
          fotosConservadas: List<String>.from(_fotosPublicadas),
          fotosNuevas: List<XFile>.from(_fotosSeleccionadas),
        );
      } else {
        List<String> fotosUrls = const [];
        if (_fotosSeleccionadas.isNotEmpty) {
          fotosUrls = await _reviewService.subirFotosResenia(
            widget.idServicio,
            _fotosSeleccionadas,
          );
        }
        await _reviewService.submitReview(
          userId: userId,
          tallerId: widget.tallerId,
          estrellas: _estrellas,
          comentario: _comentarioController.text,
          idServicio: widget.idServicio,
          fotos: fotosUrls,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        UiUtils.showSuccessSnackbar(context, '¡Gracias por tu reseña!');
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showErrorSnackbar(
          context,
          mensajeDeReglaDeNegocio(e, accion: 'No se pudo publicar tu reseña'),
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
            style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary),
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
            const SizedBox(height: 16),
            // El selector se muestra también al editar: desde FUNC-01,
            // updateReview() recibe la lista de fotos conservadas y las
            // nuevas, así que ya no se descarta nada en silencio.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in _fotosPublicadas)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          key: ValueKey('foto-existente-$url'),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          // Una URL caducada o un objeto ya borrado no debe
                          // tumbar el sheet entero: se degrada a un hueco.
                          errorBuilder: (context, _, _) => Container(
                            width: 64,
                            height: 64,
                            color: colors.textSecondary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          key: ValueKey('quitar-$url'),
                          onTap: () => _removeFotoPublicada(url),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                for (int i = 0; i < _fotosSeleccionadas.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List>(
                          future: _fotosSeleccionadas[i].readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                width: 64,
                                height: 64,
                                color: colors.textSecondary.withValues(
                                  alpha: 0.1,
                                ),
                              );
                            }
                            return Image.memory(
                              snapshot.data!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => _removeFoto(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_totalFotos < ReviewService.maxFotos)
                  InkWell(
                    key: const ValueKey('anadir-foto'),
                    onTap: _pickFoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Añadir foto',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
            if (!_canEdit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las reseñas solo se pueden editar dentro de los primeros 7 días.',
                        style: TextStyle(color: colors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: _isSubmitting
                    ? 'Guardando...'
                    : (_existingReview != null
                          ? 'Actualizar reseña'
                          : 'Publicar reseña'),
                onPressed: (_isSubmitting || !_canEdit) ? null : _submit,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
