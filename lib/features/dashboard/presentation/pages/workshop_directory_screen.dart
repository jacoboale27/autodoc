import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_skeleton.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:flutter/services.dart';

class WorkshopDirectoryScreen extends StatefulWidget {
  const WorkshopDirectoryScreen({super.key});

  @override
  State<WorkshopDirectoryScreen> createState() => _WorkshopDirectoryScreenState();
}

class _WorkshopDirectoryScreenState extends State<WorkshopDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showMap = false;
  GoogleMapController? _mapController;

  // Default center (Colombia - can be adjusted)
  static const LatLng _defaultCenter = LatLng(4.7110, -74.0721);

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      useGradient: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(colors, isDark),
            // Search Bar
            _buildSearchBar(colors, isDark),
            // Filters
            _buildFilters(colors, isDark),
            const SizedBox(height: 8),
            // Content: List or Map
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Usuarios')
                      .where('rol', whereIn: mechanicFirestoreRoles)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return AppSkeletonLayouts.workshopList();
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error al cargar talleres', style: TextStyle(color: colors.textPrimary)));
                    }

                    var docs = snapshot.data?.docs ?? [];
                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['nombre_completo'] as String?)?.toLowerCase() ?? '';
                        final spec = (data['especialidad'] as String?)?.toLowerCase() ?? '';
                        final q = _searchQuery.toLowerCase();
                        return name.contains(q) || spec.contains(q);
                      }).toList();
                    }

                    if (_showMap) {
                      return _buildMapView(docs, colors, isDark);
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: colors.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No se encontraron talleres',
                                style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildWorkshopCard(
                          tallerId: doc.id,
                          data: data,
                          colors: colors,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildHeader(AppColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: colors.primary.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => context.pop(),
          ),
          Text('Directorio de Talleres',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const Spacer(),
          // Toggle Map/List
          Container(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewToggle(Icons.list, !_showMap, colors.primary, isDark),
                _viewToggle(Icons.map_outlined, _showMap, colors.primary, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle(IconData icon, bool isActive, Color primary, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showMap = icon == Icons.map_outlined),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20,
            color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.grey)),
      ),
    );
  }

  Widget _buildSearchBar(AppColors colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: AppTextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          hintText: 'Buscar mecánicos o servicios...',
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }

  Widget _buildFilters(AppColors colors, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('Municipio', Icons.location_on, isDark, colors.textPrimary),
          const SizedBox(width: 12),
          _buildFilterChip('Especialidad', Icons.build, isDark, colors.textPrimary),
          const SizedBox(width: 12),
          _buildFilterChip('Rating', Icons.star, isDark, colors.textPrimary),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: textColor),
        ],
      ),
    );
  }

  // ======= MAP VIEW =======
  Widget _buildMapView(List<QueryDocumentSnapshot> docs, AppColors colors, bool isDark) {
    final markers = <Marker>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitud']?.toDouble();
      final lng = data['longitud']?.toDouble();
      final name = data['nombre_completo'] ?? 'Taller';

      if (lat != null && lng != null) {
        markers.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: data['especialidad'] ?? 'Mecánica General',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ));
      }
    }

    // Info card for workshops without coordinates
    final workshopsWithoutCoords = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['latitud'] == null || data['longitud'] == null;
    }).length;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: markers.isNotEmpty ? markers.first.position : _defaultCenter,
            zoom: 12,
          ),
          markers: markers,
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          style: isDark ? _darkMapStyle : null,
        ),
        // Floating info
        Positioned(
          top: 12, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B2E).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Text('${markers.length} talleres en el mapa',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: colors.textPrimary)),
                if (workshopsWithoutCoords > 0) ...[
                  const Spacer(),
                  Text('$workshopsWithoutCoords sin ubicación',
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                ],
              ],
            ),
          ),
        ),
        // Bottom list peek
        if (docs.isNotEmpty)
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _buildMapCard(data, colors, isDark);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapCard(Map<String, dynamic> data, AppColors colors, bool isDark) {
    final name = data['nombre_completo'] ?? 'Taller';
    final spec = data['especialidad'] ?? 'Mecánica General';
    final rating = data['calificacion_promedio']?.toDouble() ?? 5.0;
    final location = data['ubicacion_municipio'] ?? '';

    return GestureDetector(
      onTap: () {
        final lat = data['latitud']?.toDouble();
        final lng = data['longitud']?.toDouble();
        if (lat != null && lng != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
          );
        }
      },
      child: SizedBox(
        width: 240,
        child: AppCard(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, size: 12, color: Colors.amber[700]),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[700])),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(spec, style: TextStyle(fontSize: 12, color: colors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 13, color: colors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(location, style: TextStyle(fontSize: 11, color: colors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ======= LIST VIEW CARD =======
  void _mostrarContacto(BuildContext context, String? telefono, String nombre) {
    if (telefono == null || telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este taller no tiene teléfono registrado')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Contactar a $nombre'),
        content: SelectableText(telefono),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: telefono));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Teléfono copiado al portapapeles')),
              );
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkshopCard({
    required String tallerId,
    required Map<String, dynamic> data,
    required AppColors colors,
    required bool isDark,
  }) {
    final name = data['nombre_completo'] ?? 'Taller Sin Nombre';
    final telefono = data['telefono'] as String?;
    final imageUrl = data['foto_url'] ?? data['foto_perfil_url'];
    final specialty = data['especialidad'] ?? 'Mecánica General';
    final rating = data['calificacion_promedio']?.toDouble() ?? 5.0;
    final reviewsCount = data['total_resenias'] ?? 0;
    final location = data['ubicacion_municipio'] ?? 'Ubicación no especificada';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160, width: double.infinity,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: imageUrl != null && imageUrl.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl, fit: BoxFit.cover,
                        placeholder: (ctx, url) => AppSkeleton.card(height: 160),
                        errorWidget: (ctx, url, err) => Icon(Icons.build, size: 48, color: colors.textSecondary),
                      )
                    : Icon(Icons.build, size: 48, color: colors.textSecondary),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(name,
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(4)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star, size: 14, color: Colors.yellow[700]),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.yellow[700])),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.verified, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: Text('Especialidad: $specialty',
                          style: TextStyle(color: colors.textSecondary, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(location,
                          style: TextStyle(color: colors.textSecondary, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$reviewsCount reseña${reviewsCount == 1 ? '' : 's'}',
                                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                          ]),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => showReviewBottomSheet(
                                  context,
                                  tallerId: tallerId,
                                  tallerNombre: name,
                                ),
                                icon: const Icon(Icons.star_outline, size: 18),
                                label: const Text('Reseñar'),
                              ),
                              AppButton(
                                onPressed: () => _mostrarContacto(context, telefono, name),
                                text: 'Contactar',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }

  static const String _darkMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]}
  ]''';
}
