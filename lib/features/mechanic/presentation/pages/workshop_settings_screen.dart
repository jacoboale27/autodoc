import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';

class WorkshopSettingsScreen extends StatefulWidget {
  const WorkshopSettingsScreen({super.key});

  @override
  State<WorkshopSettingsScreen> createState() => _WorkshopSettingsScreenState();
}

class _WorkshopSettingsScreenState extends State<WorkshopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _specialtyController;
  late TextEditingController _municipalityController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userData;
    _nameController = TextEditingController(text: user?.nombreCompleto ?? '');
    _phoneController = TextEditingController(text: user?.telefono ?? '');
    _specialtyController = TextEditingController(text: user?.especialidad ?? '');
    _municipalityController = TextEditingController(text: user?.ubicacionMunicipio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _municipalityController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.userData;
      
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(
          nombreCompleto: _nameController.text.trim(),
          telefono: _phoneController.text.trim(),
          especialidad: _specialtyController.text.trim(),
          ubicacionMunicipio: _municipalityController.text.trim(),
        );

        final success = await authProvider.updateProfile(updatedUser);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil de taller actualizado exitosamente'), backgroundColor: Colors.green),
          );
        } else {
          throw authProvider.error ?? 'Error desconocido al actualizar perfil';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    final primary = theme.colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9F9FF);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.blueGrey[500]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Configuración del Taller',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                      boxShadow: [
                        if (!isDark)
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.store, color: primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Información Pública', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                  Text('Estos datos serán visibles en el directorio de talleres.', style: TextStyle(color: subTextColor, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        _buildInputField(
                          label: 'Nombre del Taller',
                          controller: _nameController,
                          icon: Icons.business,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                          validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildInputField(
                          label: 'Especialidad',
                          controller: _specialtyController,
                          icon: Icons.build_circle,
                          hint: 'Ej: Mecánica General, Frenos, Transmisión...',
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildInputField(
                          label: 'Municipio / Ubicación',
                          controller: _municipalityController,
                          icon: Icons.location_on,
                          hint: 'Ej: Bogotá, Medellín...',
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildInputField(
                          label: 'Teléfono de Contacto',
                          controller: _phoneController,
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          hint: 'Ej: +57 300 000 0000',
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Guardar Cambios', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: textColor),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: subTextColor),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
