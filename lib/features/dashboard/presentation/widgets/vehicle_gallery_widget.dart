import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/vehicle_photo_service.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

class VehicleGalleryWidget extends StatefulWidget {
  final String vehicleId;
  final AppColors colors;
  final Stream<List<VehiclePhotoModel>>? photos;
  final Future<XFile?> Function()? pickPhoto;
  final Future<void> Function(String vehicleId, XFile photo)? addPhoto;

  const VehicleGalleryWidget({
    super.key,
    required this.vehicleId,
    required this.colors,
    this.photos,
    this.pickPhoto,
    this.addPhoto,
  });

  @override
  State<VehicleGalleryWidget> createState() => _VehicleGalleryWidgetState();
}

class _VehicleGalleryWidgetState extends State<VehicleGalleryWidget> {
  /// Deja de estar montado el servicio en cada `build`: al convertir el widget
  /// en Stateful para bloquear el doble envio, un `setState` habria recreado el
  /// stream y re-suscrito la galeria en cada subida.
  VehiclePhotoService? _photoService;
  late final Stream<List<VehiclePhotoModel>> _photos;

  /// Bloquea el segundo tap mientras el selector o la subida siguen en vuelo.
  bool _subiendo = false;

  /// Perezoso de verdad: `VehiclePhotoService()` toca
  /// `FirebaseFirestore.instance` al construirse, asi que crearlo porque falte
  /// UNO de los dos seams rompia a quien inyectara solo `photos`.
  VehiclePhotoService get _servicio => _photoService ??= VehiclePhotoService();

  @override
  void initState() {
    super.initState();
    _photos = widget.photos ?? _servicio.streamPhotos(widget.vehicleId);
  }

  Future<void> _subirFoto() async {
    if (_subiendo) return;
    setState(() => _subiendo = true);
    try {
      final picked = widget.pickPhoto != null
          ? await widget.pickPhoto!()
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            );
      if (picked == null) return;
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Subiendo foto...')));
      // Sin este try/catch la excepcion se perdia y el snackbar
      // "Subiendo foto..." se quedaba colgado: el usuario no tenia
      // forma de saber que la subida habia fallado.
      try {
        if (widget.addPhoto != null) {
          await widget.addPhoto!(widget.vehicleId, picked);
        } else {
          await _servicio.addPhoto(widget.vehicleId, picked);
        }
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(content: Text('Foto añadida')));
      } catch (e) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              mensajeSeguroDeError(e, accion: 'No se pudo subir la foto'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Padding(
      // El gutter horizontal lo pone AppPageBody en VehicleProfileScreen
      // (fuente única): duplicarlo aquí desbordaba a 375px.
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Galería de Fotos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_a_photo, color: colors.primary),
                onPressed: _subiendo ? null : _subirFoto,
              ),
            ],
          ),
          StreamBuilder<List<VehiclePhotoModel>>(
            stream: _photos,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Text(
                  'No hay fotos en la galería.',
                  style: TextStyle(color: colors.textSecondary),
                );
              }

              final fotos = snapshot.data!;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Por ancho máximo de miniatura y no 3 columnas fijas: en
                // escritorio cada foto medía casi 400 px de lado (observaciones
                // del 2026-09-19). En un teléfono siguen saliendo 3.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: fotos.length,
                itemBuilder: (context, index) {
                  final foto = fotos[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(
                            foto: foto,
                            vehicleId: widget.vehicleId,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: foto.id,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(foto.url, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final VehiclePhotoModel foto;
  final String vehicleId;

  const FullScreenImageViewer({
    super.key,
    required this.foto,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar foto'),
                  content: const Text('¿Estás seguro de eliminar esta foto?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                if (context.mounted) {
                  Navigator.pop(context); // close full screen
                }
                await VehiclePhotoService().deletePhoto(
                  vehicleId,
                  foto.id,
                  foto.url,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(tag: foto.id, child: Image.network(foto.url)),
      ),
    );
  }
}
