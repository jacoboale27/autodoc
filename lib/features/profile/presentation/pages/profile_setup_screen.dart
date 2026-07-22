import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedRole = 'Propietario'; // 'Propietario' or 'Mecanico'
  bool _notificationsEnabled = true;
  XFile? _imageFile;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = appColors.primary;
    final secondaryColor = appColors.secondary;

    return Scaffold(
      backgroundColor: appColors.surface,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: appColors.surface.withValues(alpha: 0.75),
              elevation: 0,
              centerTitle: false,
              title: Row(
                children: [
                  Icon(Icons.directions_car, color: primaryColor, size: Responsive.iconSize(context, 22)),
                  const SizedBox(width: 8),
                  Text(
                    'AutoDoc',
                    style: GoogleFonts.montserratAlternates(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.fontSize(context, 18),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: Icon(Icons.logout, color: appColors.textSecondary, size: 16),
                  label: Text(
                    'Salir',
                    style: GoogleFonts.inter(
                      color: appColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 24.0, left: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PASO 1 DE 1',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.bold,
                          color: appColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 5,
                        decoration: BoxDecoration(
                          color: appColors.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background ambient glowing decoration for premium dark look
          if (isDarkMode) ...[
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.18),
                      primaryColor.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      secondaryColor.withValues(alpha: 0.15),
                      secondaryColor.withValues(alpha: 0.01),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                children: [
                  // Main Glass Panel Container
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? appColors.surfaceContainer.withValues(alpha: 0.75)
                          : appColors.surfaceContainer.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDarkMode
                            ? appColors.outline.withValues(alpha: 0.5)
                            : appColors.outline.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Padding(
                          padding: EdgeInsets.all(Responsive.padding(context, 32.0)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                '¡Bienvenido a AutoDoc!',
                                style: GoogleFonts.montserrat(
                                  fontSize: Responsive.fontSize(context, 26),
                                  fontWeight: FontWeight.bold,
                                  color: appColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
                              const SizedBox(height: 8),
                              
                              // Subtitle with high contrast
                              Text(
                                'Configura tu perfil para obtener diagnósticos personalizados y alertas precisas para tu vehículo.',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.fontSize(context, 14),
                                  color: appColors.textSecondary,
                                  height: 1.4,
                                ),
                              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                              const SizedBox(height: 32),
                              
                              // Avatar / Profile Photo Picker
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryColor.withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: primaryColor.withValues(alpha: 0.6),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(alpha: 0.2),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _imageFile != null
                                            ? FutureBuilder<List<int>>(
                                                future: _imageFile!.readAsBytes().then((b) => b.toList()),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData) {
                                                    return Image.memory(
                                                      Uint8List.fromList(snapshot.data!),
                                                      fit: BoxFit.cover,
                                                      width: 104,
                                                      height: 104,
                                                    );
                                                  }
                                                  return Center(
                                                    child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.person_rounded,
                                                size: Responsive.iconSize(context, 54),
                                                color: primaryColor,
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                                          if (pickedFile != null) {
                                            setState(() => _imageFile = pickedFile);
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(Responsive.padding(context, 8)),
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: appColors.surface, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            color: isDarkMode ? appColors.surface : Colors.white,
                                            size: Responsive.iconSize(context, 16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().scale(delay: 150.ms, duration: 400.ms, curve: Curves.easeOutBack),
                              const SizedBox(height: 32),

                              // Full Name Label
                              Text(
                                'NOMBRE COMPLETO',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.fontSize(context, 11),
                                  fontWeight: FontWeight.bold,
                                  color: appColors.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Full Name Input Field
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? appColors.surfaceVariant.withValues(alpha: 0.6)
                                      : appColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: appColors.outline.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.fontSize(context, 15),
                                    fontWeight: FontWeight.w500,
                                    color: appColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ej. Juan Pérez',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: Responsive.fontSize(context, 15),
                                      color: appColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: appColors.textSecondary,
                                      size: Responsive.iconSize(context, 20),
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Role Selection Label
                              Text(
                                'SELECCIONA TU ROL',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.fontSize(context, 11),
                                  fontWeight: FontWeight.bold,
                                  color: appColors.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Role Selection Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildRoleCard(
                                      title: 'Propietario',
                                      icon: Icons.person_outline_rounded,
                                      isSelected: _selectedRole == 'Propietario',
                                      onTap: () => setState(() => _selectedRole = 'Propietario'),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildRoleCard(
                                      title: 'Mecánico',
                                      icon: Icons.build_circle_outlined,
                                      isSelected: _selectedRole == 'Mecanico',
                                      onTap: () => setState(() => _selectedRole = 'Mecanico'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Role Explanation Banner
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  key: ValueKey<String>(_selectedRole),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: isDarkMode ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedRole == 'Propietario'
                                              ? 'Como propietario, podrás agregar vehículos a tu garaje virtual y dar seguimiento a sus mantenimientos.'
                                              : 'Como mecánico, podrás administrar tu taller, registrar servicios y conectar con propietarios de vehículos.',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.fontSize(context, 12.5),
                                            color: appColors.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Preferences Label
                              Text(
                                'PREFERENCIAS',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.fontSize(context, 11),
                                  fontWeight: FontWeight.bold,
                                  color: appColors.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Maintenance Notifications Switch Row
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? appColors.surfaceVariant.withValues(alpha: 0.5)
                                      : appColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: appColors.outline.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications_active_rounded,
                                        color: primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Notificaciones de mantenimiento',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: Responsive.fontSize(context, 14),
                                              color: appColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Alertas sobre cambios de aceite, frenos y revisiones.',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.fontSize(context, 12),
                                              color: appColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _notificationsEnabled,
                                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                                      activeColor: primaryColor,
                                      activeTrackColor: primaryColor.withValues(alpha: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 24),
          vertical: Responsive.padding(context, 16),
        ),
        decoration: BoxDecoration(
          color: appColors.surface,
          border: Border(
            top: BorderSide(
              color: appColors.outline.withValues(alpha: 0.3),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final authSession = context.read<AuthSessionProvider>();
                      final profileProvider = context.read<UserProfileProvider>();
                      final user = authSession.user ?? FirebaseAuth.instance.currentUser;
                      final name = _nameController.text.trim();
                      
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Por favor, ingresa tu nombre completo'),
                            backgroundColor: appColors.error,
                          ),
                        );
                        return;
                      }

                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Error: Sesión no encontrada. Vuelve a iniciar sesión.'),
                            backgroundColor: appColors.error,
                          ),
                        );
                        return;
                      }

                      try {
                        setState(() => _isLoading = true);
                        
                        UserModel userModel = UserModel(
                          idUsuario: user.uid,
                          nombreCompleto: name,
                          correo: user.email ?? '',
                          rol: _selectedRole,
                          fechaRegistro: DateTime.now(),
                        );
                        
                        final success = await profileProvider.updateProfile(userModel, imageFile: _imageFile, isNewUser: true);
                        
                        if (success) {
                          await user.updateDisplayName(name);
                          await user.reload();
                          
                          if (context.mounted) {
                            final role = _selectedRole.trim().toLowerCase();
                            if (role == 'mecanico') {
                              context.go('/mechanic_dashboard');
                            } else {
                              context.go('/dashboard');
                            }
                          }
                        } else {
                          throw profileProvider.error ?? 'Error desconocido al guardar el perfil';
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al guardar: $e'),
                              backgroundColor: appColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDarkMode ? appColors.surface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _isLoading 
                ? [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: isDarkMode ? appColors.surface : Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Guardando...',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.fontSize(context, 16),
                      ),
                    ),
                  ]
                : [
                    Text(
                      'Finalizar Configuración',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.fontSize(context, 16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final appColors = context.appColors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = appColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.1)
              : (isDarkMode ? appColors.surfaceVariant.withValues(alpha: 0.4) : appColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : appColors.outline.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : appColors.textSecondary,
              size: Responsive.iconSize(context, 34),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: Responsive.fontSize(context, 14),
                color: isSelected ? appColors.textPrimary : appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
