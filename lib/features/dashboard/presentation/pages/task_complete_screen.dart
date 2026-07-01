import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/utils/responsive.dart';

class TaskCompleteScreen extends StatefulWidget {
  final MaintenanceTask task;
  final int currentKm;
  const TaskCompleteScreen({super.key, required this.task, required this.currentKm});

  @override
  State<TaskCompleteScreen> createState() => _TaskCompleteScreenState();
}

class _TaskCompleteScreenState extends State<TaskCompleteScreen> {
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  File? _receiptImage;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _receiptImage = File(pickedFile.path));
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = const Color(0xFF522C81);
    final bgColor = isDark ? const Color(0xFF18141E) : const Color(0xFFF7F6F8);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.5);
    final status = widget.task.getStatus(widget.currentKm);
    final statusColor = status == MaintenanceStatus.critical
        ? Colors.red
        : status == MaintenanceStatus.preventive
            ? Colors.amber[700]!
            : Colors.green;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8, right: 16, bottom: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(bottom: BorderSide(color: primary.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: isDark ? Colors.white70 : Colors.grey[700]),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Completar Servicio',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primary)),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.padding(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task summary card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(Responsive.padding(context, 20)),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.build_circle_outlined,
                                    color: statusColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.task.nombre,
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17, color: textColor)),
                                    const SizedBox(height: 2),
                                    Text(widget.task.getStatusLabel(widget.currentKm),
                                        style: GoogleFonts.inter(
                                            fontSize: 12, fontWeight: FontWeight.w600,
                                            color: statusColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(Responsive.padding(context, 12)),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: isDark ? 0.1 : 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _infoItem('Km Actual', NumberFormat('#,###').format(widget.currentKm), textColor, subTextColor),
                                Container(width: 1, height: 30, color: subTextColor.withValues(alpha: 0.2)),
                                _infoItem('Último', '${NumberFormat('#,###').format(widget.task.ultimoKm)} km', textColor, subTextColor),
                                Container(width: 1, height: 30, color: subTextColor.withValues(alpha: 0.2)),
                                _infoItem('Fecha', DateFormat('dd/MM/yy').format(widget.task.fechaUltimoServicio), textColor, subTextColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text('DETALLES DEL SERVICIO',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1.2, color: subTextColor)),
                  const SizedBox(height: 4),
                  Text('Registra la información del mantenimiento realizado.',
                      style: GoogleFonts.inter(fontSize: 13, color: subTextColor)),
                  const SizedBox(height: 20),

                  // Cost field
                  _buildInputCard(
                    icon: Icons.attach_money,
                    label: 'Costo Total (Opcional)',
                    child: TextField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(fontSize: 18, color: textColor),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    isDark: isDark, primary: primary, cardColor: cardColor, borderColor: borderColor,
                  ),
                  const SizedBox(height: 12),

                  // Notes field
                  _buildInputCard(
                    icon: Icons.note_alt_outlined,
                    label: 'Notas / Taller / Refacciones',
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Ej: Se usó aceite sintético 5W-30...',
                        hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    isDark: isDark, primary: primary, cardColor: cardColor, borderColor: borderColor,
                  ),

                  const SizedBox(height: 24),
                  Text('EVIDENCIA (RECIBO O FOTO)',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1.2, color: subTextColor)),
                  const SizedBox(height: 4),
                  Text('Para validar el servicio, adjunta una foto del recibo o de la pieza cambiada.',
                      style: GoogleFonts.inter(fontSize: 13, color: subTextColor)),
                  const SizedBox(height: 12),

                  if (_receiptImage != null)
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
                            image: DecorationImage(
                              image: FileImage(_receiptImage!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _receiptImage = null),
                            child: Container(
                              padding: EdgeInsets.all(Responsive.padding(context, 6)),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8, left: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 10), vertical: Responsive.padding(context, 4)),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text('Imagen adjunta', style: GoogleFonts.inter(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _photoButton(
                            icon: Icons.camera_alt,
                            label: 'Cámara',
                            onTap: () => _pickImage(ImageSource.camera),
                            isDark: isDark, primary: primary, cardColor: cardColor, borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _photoButton(
                            icon: Icons.photo_library,
                            label: 'Galería',
                            onTap: () => _pickImage(ImageSource.gallery),
                            isDark: isDark, primary: primary, cardColor: cardColor, borderColor: borderColor,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 36),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _receiptImage == null) ? null : _submitCompletion,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle),
                      label: Text(_isLoading ? 'Guardando...' : 'Confirmar y Validar',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primary.withValues(alpha: 0.4),
                        disabledForegroundColor: Colors.white54,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  if (_receiptImage == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text('* Se requiere evidencia fotográfica para validar',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.red.withValues(alpha: 0.7))),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: subTextColor)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required Widget child,
    required bool isDark,
    required Color primary,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: primary.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color primary,
    required Color cardColor,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withValues(alpha: 0.2), style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(icon, color: primary, size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCompletion() async {
    setState(() => _isLoading = true);
    try {
      final cost = double.tryParse(_costController.text) ?? 0.0;
      await context.read<AlertProvider>().userCompleteTask(
        taskId: widget.task.id,
        currentKm: widget.currentKm,
        cost: cost,
        notes: _notesController.text.trim(),
        receiptImage: _receiptImage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio validado y registrado en historial ✓')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
