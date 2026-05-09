import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/providers/theme_provider.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;
  const ServiceHistoryScreen({super.key, required this.vehicleId});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  String _filter = 'Todos'; // 'Todos', 'Manual', 'Taller'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final primary = theme.primaryColor;
    final bgLight = const Color(0xFFF7F6F8);
    final bgDark = const Color(0xFF18141E);
    final bgColor = isDark ? bgDark : bgLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Historial de Servicios',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildFilterTab('Todos', primary, isDark),
                  _buildFilterTab('Manual', primary, isDark),
                  _buildFilterTab('Taller', primary, isDark),
                ],
              ),
            ),
          ),
          
          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('servicios')
                  .where('id_vehiculo', isEqualTo: widget.vehicleId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(primary, subTextColor);
                }

                final docs = snapshot.data!.docs;
                final allRecords = docs.map((doc) => ServiceRecordModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                allRecords.sort((a, b) => b.fecha.compareTo(a.fecha));
                
                final filteredRecords = allRecords.where((record) {
                  if (_filter == 'Todos') return true;
                  final isManual = record.idTaller == 'Manual (Propietario)';
                  if (_filter == 'Manual') return isManual;
                  if (_filter == 'Taller') return !isManual;
                  return true;
                }).toList();

                if (filteredRecords.isEmpty) {
                  return _buildEmptyState(primary, subTextColor);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
                    return _buildServiceCard(record, primary, isDark, textColor, subTextColor, context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primary, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No hay servicios registrados',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Los mantenimientos aparecerán aquí',
            style: TextStyle(color: subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, Color primary, bool isDark) {
    final isSelected = _filter == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(ServiceRecordModel record, Color primary, bool isDark, Color textColor, Color subTextColor, BuildContext context) {
    final isManual = record.idTaller == 'Manual (Propietario)';
    
    // Select Icon based on service type
    IconData serviceIcon = Icons.build;
    final lowerName = record.tipoServicio?.toLowerCase() ?? '';
    if (lowerName.contains('aceite')) {
      serviceIcon = Icons.oil_barrel_outlined;
    } else if (lowerName.contains('llanta') || lowerName.contains('neumático') || lowerName.contains('alineación') || lowerName.contains('balanceo')) {
      serviceIcon = Icons.tire_repair_outlined;
    } else if (lowerName.contains('freno') || lowerName.contains('pastilla')) {
      serviceIcon = Icons.stop_circle_outlined;
    } else if (lowerName.contains('batería')) {
      serviceIcon = Icons.battery_charging_full_outlined;
    } else if (lowerName.contains('líquido') || lowerName.contains('refrigerante') || lowerName.contains('anticongelante')) {
      serviceIcon = Icons.water_drop_outlined;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282032).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(serviceIcon, color: primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.tipoServicio ?? 'Servicio',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(record.fecha)} • ${record.kilometrajeServicio ?? '--'} km',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.costo != null && record.costo! > 0)
                Text(
                  '\$${record.costo!.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isManual ? Colors.blueGrey.withValues(alpha: 0.1) : primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isManual ? Icons.person : Icons.store,
                      size: 14,
                      color: isManual ? Colors.blueGrey : primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isManual ? 'Propietario' : 'Taller',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isManual ? Colors.blueGrey : primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.fotoFacturaUrl != null && record.fotoFacturaUrl!.isNotEmpty)
                GestureDetector(
                  onTap: () => _showImageDialog(context, record.fotoFacturaUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text('Evidencia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (record.descripcion != null && record.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.descripcion!,
              style: TextStyle(color: subTextColor, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
