import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

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
    _municipalityController =
        TextEditingController(text: user?.ubicacionMunicipio ?? '');
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
            SnackBar(
              content: const Text('Perfil de taller actualizado exitosamente'),
              backgroundColor: context.appColors.secondary,
            ),
          );
        } else {
          throw authProvider.error ?? 'Error desconocido al actualizar perfil';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.appColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: isMobile
          ? AppBar(
              backgroundColor: colors.surfaceContainer,
              elevation: 0,
              title: Text(
                'Panel de Taller',
                style: GoogleFonts.montserrat(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.textPrimary),
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isMobile) _buildTopBar(isDark, colors),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isMobile) ...[
                                Text(
                                  'Configuración del Taller',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey[200]!,
                                  ),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
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
                                            color: primary.withValues(
                                                alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.store,
                                              color: primary),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Información Pública',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                'Estos datos serán visibles en el directorio de talleres.',
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
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
                                      colors: colors,
                                      isDark: isDark,
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                              ? 'Requerido'
                                              : null,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInputField(
                                      label: 'Especialidad',
                                      controller: _specialtyController,
                                      icon: Icons.build_circle,
                                      hint:
                                          'Ej: Mecánica General, Frenos, Transmisión...',
                                      colors: colors,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInputField(
                                      label: 'Municipio / Ubicación',
                                      controller: _municipalityController,
                                      icon: Icons.location_on,
                                      hint: 'Ej: Bogotá, Medellín...',
                                      colors: colors,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInputField(
                                      label: 'Teléfono de Contacto',
                                      controller: _phoneController,
                                      icon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                      hint: 'Ej: +57 300 000 0000',
                                      colors: colors,
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Guardar Cambios',
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark, AppColors colors) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white10
                : colors.surfaceContainer.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'CONFIGURACIÓN',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    required AppColors colors,
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
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: colors.textPrimary),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: colors.textSecondary),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
