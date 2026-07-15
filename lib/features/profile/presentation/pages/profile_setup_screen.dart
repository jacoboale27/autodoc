import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:autodoc/core/utils/responsive.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedRole = 'Propietario'; // 'Propietario' or 'Mecanico'
  bool _notificationsEnabled = true;
  File? _imageFile;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryPurple = isDarkMode ? const Color(0xFFD0BCFF) : const Color(0xFF522C81);
    const mintColor = Color(0xFF81E6D9);

    return Scaffold(
      backgroundColor: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF9F9FF),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: isDarkMode ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7),
              elevation: 0,
              centerTitle: false,
              title: Row(
                children: [
                  Icon(Icons.directions_car, color: primaryPurple),
                  const SizedBox(width: 8),
                  Text(
                    'AutoDoc',
                    style: GoogleFonts.montserratAlternates(
                      color: primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.fontSize(context, 18),
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PASO 1 DE 1',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: mintColor,
                              borderRadius: BorderRadius.circular(3),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode 
                ? [Theme.of(context).scaffoldBackgroundColor, Theme.of(context).scaffoldBackgroundColor]
                : [const Color(0xFFFFFFFF), const Color(0xFFF0F4F8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              children: [
                // Glass Panel
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPurple.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Padding(
                        padding: EdgeInsets.all(Responsive.padding(context, 32.0)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Bienvenido a AutoDoc!',
                              style: GoogleFonts.montserrat(
                                fontSize: Responsive.fontSize(context, 24),
                                fontWeight: FontWeight.bold,
                                color: primaryPurple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Configura tu perfil para obtener diagnósticos personalizados y alertas precisas para tu vehículo.',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.fontSize(context, 14),
                                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Foto de Perfil
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryPurple.withValues(alpha: 0.1),
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _imageFile != null
                                          ? Image.file(_imageFile!, fit: BoxFit.cover)
                                          : Icon(Icons.person, size: Responsive.iconSize(context, 50), color: primaryPurple.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () async {
                                        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                                        if (pickedFile != null) {
                                          setState(() => _imageFile = File(pickedFile.path));
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(Responsive.padding(context, 8)),
                                        decoration: BoxDecoration(
                                          color: primaryPurple,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.camera_alt, color: Colors.white, size: Responsive.iconSize(context, 16)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Nombre Completo
                            Text(
                              'NOMBRE COMPLETO',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Ej. Juan Pérez',
                                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                                filled: true,
                                fillColor: isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: mintColor, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Selección de Rol
                            Text(
                              'SELECCIONA TU ROL',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildRoleCard(
                                    title: 'Propietario',
                                    icon: Icons.person_outline,
                                    isSelected: _selectedRole == 'Propietario',
                                    onTap: () => setState(() => _selectedRole = 'Propietario'),
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                            
                            // Mensaje Condicional
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey<String>(_selectedRole),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: mintColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: mintColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: mintColor, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedRole == 'Propietario' 
                                            ? 'Como propietario, tu siguiente paso será registrar tu primer vehículo en el garaje virtual.'
                                            : 'Como mecánico, más adelante podrás registrar los datos de tu taller para comenzar a recibir servicios.',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.fontSize(context, 12),
                                          color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            Text(
                              'PREFERENCIAS',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Notificaciones
                            Container(
                              padding: EdgeInsets.all(Responsive.padding(context, 16)),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: mintColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.notifications_active, color: Colors.teal[700]),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notificaciones de mantenimiento',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: Responsive.fontSize(context, 14),
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Alertas sobre cambios de aceite, frenos y más.',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.fontSize(context, 12),
                                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _notificationsEnabled,
                                    onChanged: (val) => setState(() => _notificationsEnabled = val),
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: mintColor,
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
      ),
      bottomSheet: Container(
        padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 24), vertical: Responsive.padding(context, 16)),
        decoration: BoxDecoration(
          color: isDarkMode ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.8),
          border: Border(top: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                final userSession = context.read<UserSessionProvider>();
                // Usar currentUser directamente en caso de que el provider no haya actualizado
                final user = userSession.user ?? FirebaseAuth.instance.currentUser;
                final name = _nameController.text.trim();
                
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, ingresa tu nombre completo'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Sesión no encontrada. Vuelve a iniciar sesión.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  setState(() => _isLoading = true); // Need to add _isLoading state if not present, or use authProvider.isLoading
                  
                  // Save to Firestore
                  UserModel userModel = UserModel(
                    idUsuario: user.uid,
                    nombreCompleto: name,
                    correo: user.email ?? '',
                    rol: _selectedRole,
                    fechaRegistro: DateTime.now(),
                  );
                  
                  // Use UserSessionProvider.updateProfile to handle image upload and Firestore update
                  final success = await userSession.updateProfile(userModel, imageFile: _imageFile);
                  
                  if (success) {
                    // Update Firebase Auth displayName if needed
                    await user.updateDisplayName(name);
                    await user.reload(); // update instance
                    
                    if (context.mounted) {
                      final role = _selectedRole.trim().toLowerCase();
                      if (role == 'mecanico') {
                        context.go('/mechanic_dashboard');
                      } else {
                        context.go('/dashboard');
                      }
                    }
                  } else {
                    throw userSession.error ?? 'Error desconocido al guardar el perfil';
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: mintColor,
                foregroundColor: const Color(0xFF522C81),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _isLoading 
                ? [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Color(0xFF522C81),
                        strokeWidth: 2,
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
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const mintColor = Color(0xFF81E6D9);
    final primaryPurple = isDarkMode ? const Color(0xFFD0BCFF) : const Color(0xFF522C81);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? mintColor.withValues(alpha: 0.1) : (isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? mintColor : (isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: primaryPurple,
              size: Responsive.iconSize(context, 32),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: Responsive.fontSize(context, 14),
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
