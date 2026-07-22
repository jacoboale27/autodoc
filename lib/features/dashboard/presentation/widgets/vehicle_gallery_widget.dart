import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/vehicle_photo_service.dart';

class VehicleGalleryWidget extends StatelessWidget {
  final String vehicleId;
  final AppColors colors;

  const VehicleGalleryWidget({super.key, required this.vehicleId, required this.colors});

  @override
  Widget build(BuildContext context) {
    final photoService = VehiclePhotoService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Galería de Fotos',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_a_photo, color: colors.primary),
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo foto...')));
                    await photoService.addPhoto(vehicleId, picked);
                  }
                },
              ),
            ],
          ),
          StreamBuilder<List<VehiclePhotoModel>>(
            stream: photoService.streamPhotos(vehicleId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Text('No hay fotos en la galería.', style: TextStyle(color: colors.textSecondary));
              }

              final fotos = snapshot.data!;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: fotos.length,
                itemBuilder: (context, index) {
                  final foto = fotos[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(foto: foto, vehicleId: vehicleId)));
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

  const FullScreenImageViewer({super.key, required this.foto, required this.vehicleId});

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
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                if (context.mounted) {
                  Navigator.pop(context); // close full screen
                }
                await VehiclePhotoService().deletePhoto(vehicleId, foto.id, foto.url);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: foto.id,
          child: Image.network(foto.url),
        ),
      ),
    );
  }
}
