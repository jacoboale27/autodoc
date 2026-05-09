import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';

class TaskConfigScreen extends StatefulWidget {
  final MaintenanceTask task;
  const TaskConfigScreen({super.key, required this.task});

  @override
  State<TaskConfigScreen> createState() => _TaskConfigScreenState();
}

class _TaskConfigScreenState extends State<TaskConfigScreen> {
  late TextEditingController _kmController;
  late TextEditingController _monthsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kmController = TextEditingController(text: widget.task.frecuenciaKm.toString());
    _monthsController = TextEditingController(text: widget.task.frecuenciaMeses.toString());
  }

  @override
  void dispose() {
    _kmController.dispose();
    _monthsController.dispose();
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
                    Text('Configurar Tarea',
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.build_circle_outlined,
                                  color: primary, size: 28),
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
                                  const SizedBox(height: 4),
                                  Text(
                                    'Último servicio: ${widget.task.ultimoKm} km',
                                    style: TextStyle(fontSize: 13, color: subTextColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text('FRECUENCIA DE MANTENIMIENTO',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1.2, color: subTextColor)),
                  const SizedBox(height: 4),
                  Text('Ajusta cada cuántos kilómetros y meses se debe realizar este servicio.',
                      style: GoogleFonts.inter(fontSize: 13, color: subTextColor)),
                  const SizedBox(height: 20),

                  // KM field
                  _buildField(
                    label: 'Frecuencia en Kilómetros',
                    controller: _kmController,
                    suffix: 'km',
                    icon: Icons.speed,
                    isDark: isDark, primary: primary, textColor: textColor,
                    cardColor: cardColor, borderColor: borderColor,
                  ),
                  const SizedBox(height: 16),

                  // Months field
                  _buildField(
                    label: 'Frecuencia en Meses',
                    controller: _monthsController,
                    suffix: 'meses',
                    icon: Icons.calendar_month,
                    isDark: isDark, primary: primary, textColor: textColor,
                    cardColor: cardColor, borderColor: borderColor,
                  ),

                  const SizedBox(height: 28),
                  // Quick presets
                  Text('PREAJUSTES RÁPIDOS',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1.2, color: subTextColor)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _presetChip('3,000 km / 3 m', 3000, 3, primary, isDark),
                      _presetChip('5,000 km / 6 m', 5000, 6, primary, isDark),
                      _presetChip('10,000 km / 12 m', 10000, 12, primary, isDark),
                      _presetChip('20,000 km / 24 m', 20000, 24, primary, isDark),
                    ],
                  ),

                  const SizedBox(height: 40),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Guardar Configuración',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required IconData icon,
    required bool isDark,
    required Color primary,
    required Color textColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  decoration: InputDecoration(
                    suffixText: suffix,
                    suffixStyle: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, int km, int months, Color primary, bool isDark) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: primary.withValues(alpha: isDark ? 0.15 : 0.08),
      labelStyle: TextStyle(color: primary),
      side: BorderSide(color: primary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        setState(() {
          _kmController.text = km.toString();
          _monthsController.text = months.toString();
        });
      },
    );
  }

  Future<void> _saveConfig() async {
    final km = int.tryParse(_kmController.text);
    final months = int.tryParse(_monthsController.text);
    if (km == null || km <= 0 || months == null || months <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa valores válidos mayores a 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AlertProvider>().userUpdateTaskFull(
        widget.task.id, km, months,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
