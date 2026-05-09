import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

class WorkshopDirectoryScreen extends StatefulWidget {
  const WorkshopDirectoryScreen({super.key});

  @override
  State<WorkshopDirectoryScreen> createState() => _WorkshopDirectoryScreenState();
}

class _WorkshopDirectoryScreenState extends State<WorkshopDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primary = theme.colorScheme.primary;
    final bgColorStart = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgColorEnd = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F4F8);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.blueGrey[500]!;
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                  border: Border(bottom: BorderSide(color: primary.withValues(alpha: 0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () => context.pop(),
                        ),
                        Text(
                          'Directorio de Talleres',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.map, color: textColor),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Buscar mecánicos o servicios...',
                      hintStyle: TextStyle(color: subTextColor),
                      prefixIcon: Icon(Icons.search, color: subTextColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('Municipio', Icons.location_on, isDark, textColor),
                    const SizedBox(width: 12),
                    _buildFilterChip('Especialidad', Icons.build, isDark, textColor),
                    const SizedBox(width: 12),
                    _buildFilterChip('Rating', Icons.star, isDark, textColor),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // List of Workshops
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('usuarios')
                      .where('rol', isEqualTo: 'Taller')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error al cargar talleres', style: TextStyle(color: textColor)));
                    }

                    var docs = snapshot.data?.docs ?? [];
                    
                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['nombre_completo'] as String?)?.toLowerCase() ?? '';
                        return name.contains(_searchQuery.toLowerCase());
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No se encontraron talleres',
                          style: TextStyle(color: subTextColor, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildWorkshopCard(
                          name: data['nombre_completo'] ?? 'Taller Sin Nombre',
                          imageUrl: data['foto_url'] ?? data['foto_perfil_url'],
                          specialty: data['especialidad'] ?? 'Mecánica General',
                          rating: data['calificacion_promedio']?.toDouble() ?? 5.0, // Assuming field exists or default 5.0
                          reviewsCount: data['total_resenias'] ?? 0, 
                          location: data['ubicacion_municipio'] ?? 'Ubicación no especificada',
                          isDark: isDark,
                          primary: primary,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          cardColor: cardColor,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

  Widget _buildWorkshopCard({
    required String name,
    String? imageUrl,
    required String specialty,
    required double rating,
    required int reviewsCount,
    required String location,
    required bool isDark,
    required Color primary,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workshop Image
              Container(
                height: 160,
                width: double.infinity,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Icon(Icons.build, size: 48, color: subTextColor),
                      )
                    : Icon(Icons.build, size: 48, color: subTextColor),
              ),
              
              // Workshop Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.yellow[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.yellow[700]),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.yellow[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: subTextColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Especialidad: $specialty',
                            style: TextStyle(color: subTextColor, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: subTextColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(color: subTextColor, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$reviewsCount reseñas', style: TextStyle(fontSize: 12, color: subTextColor)),
                              const SizedBox(height: 2),
                              Text('Abierto • Cierra 18:00', style: TextStyle(fontSize: 12, color: subTextColor)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Contactar', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}
