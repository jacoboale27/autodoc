import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/features/profile/presentation/pages/about_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<UserSessionProvider>().userData;
    if (user != null) {
      _nameController.text = user.nombreCompleto;
      _emailController.text = user.correo;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final sessionProvider = context.read<UserSessionProvider>();
    final currentUser = sessionProvider.userData;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(
      nombreCompleto: _nameController.text,
    );

    final success = await sessionProvider.updateProfile(updatedUser, imageFile: _imageFile);
    
    if (!mounted) return;
    
    if (success) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.upProfileUpdatedSuccess)),
      );
    } else if (sessionProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.upErrorUploadingImage(sessionProvider.error!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryPurple = theme.colorScheme.primary;
    final accentColor = const Color(0xFF98FFD9);
    final bgColorStart = isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F6F8);
    final bgColorEnd = isDark ? const Color(0xFF0F172A) : const Color(0xFFECE9F1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final sessionProvider = context.watch<UserSessionProvider>();
    final user = sessionProvider.userData;
    final isLoading = sessionProvider.isLoading;

    if (isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.upProfileTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: Responsive.iconSize(context, 64), color: Colors.grey),
              const SizedBox(height: 16),
              Text(context.l10n.upProfileDataNotFound, style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(sessionProvider.error ?? context.l10n.upPleaseCompleteSetup, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/profile_setup'),
                child: Text(context.l10n.upSetupProfile),
              ),
              TextButton(
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await context.read<AuthProvider>().signOut();
                  router.go('/login');
                },
                child: Text(context.l10n.upSignOut, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, primaryPurple, textColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(Responsive.padding(context, 24.0)),
                  child: Column(
                    children: [
                      _buildProfileHeader(user, primaryPurple, accentColor, textColor),
                      const SizedBox(height: 40),
                      _buildInfoSection(user, primaryPurple, isDark),
                      const SizedBox(height: 24),
                      _buildSettingsSection(context, primaryPurple, isDark),
                      const SizedBox(height: 40),
                      _buildLogoutButton(context, primaryPurple),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              onPressed: isLoading ? null : _saveProfile,
              backgroundColor: primaryPurple,
              label: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(context.l10n.upSaveChanges, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              icon: isLoading ? null : const Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildAppBar(BuildContext context, Color primary, Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 16.0), vertical: Responsive.padding(context, 8.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new, size: Responsive.iconSize(context, 20)),
          ),
          Text(
            context.l10n.upMyProfile,
            style: GoogleFonts.inter(
              fontSize: Responsive.fontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, color: primary),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, Color primary, Color accent, Color textColor) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: user.fotoPerfilUrl ?? 'https://www.w3schools.com/howto/img_avatar.png',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(
                          color: primary.withValues(alpha: 0.1),
                          child: Icon(Icons.person, size: Responsive.iconSize(context, 60), color: primary),
                        ),
                      ),
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: EdgeInsets.all(Responsive.padding(context, 8)),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.camera_alt, color: Colors.white, size: Responsive.iconSize(context, 20)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          user.nombreCompleto,
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 24),
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          user.rol,
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(UserModel user, Color primary, bool isDark) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoField(context.l10n.upFullName, _nameController, Icons.person_outline, primary, _isEditing, isDark),
          const SizedBox(height: 24),
          _buildInfoField(context.l10n.upEmailAddress, _emailController, Icons.email_outlined, primary, false, isDark), // Email usually not editable here
          const SizedBox(height: 24),
          _buildStaticField(
            context.l10n.upMemberSince,
            DateFormat('MMM yyyy').format(user.fechaRegistro),
            Icons.calendar_today_outlined,
            primary,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, Color primary, bool isDark) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.upSettings,
            style: GoogleFonts.inter(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeOption(
            context,
            context.l10n.upDarkMode,
            context.l10n.upSwitchTheme,
            Icons.dark_mode_outlined,
            themeProvider.themeMode == ThemeMode.dark,
            (value) {
              themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            },
            isDark,
          ),
          const Divider(height: 32),
          _buildThemeOption(
            context,
            context.l10n.upFollowSystem,
            context.l10n.upUseSystemTheme,
            Icons.settings_brightness_outlined,
            themeProvider.themeMode == ThemeMode.system,
            (value) {
              themeProvider.setThemeMode(value ? ThemeMode.system : (isDark ? ThemeMode.dark : ThemeMode.light));
            },
            isDark,
          ),
          const Divider(height: 32),
          _buildThemeOption(
            context,
            'Idioma / Language',
            'EN (Activado) / ES (Desactivado)',
            Icons.language_outlined,
            languageProvider.currentLocale.languageCode == 'en',
            (value) {
              languageProvider.changeLanguage(value ? 'en' : 'es');
            },
            isDark,
          ),
          const Divider(height: 32),
          _buildActionOption(
            context,
            'Acerca de AutoDoc',
            'Versión, créditos y legal',
            Icons.info_outline,
            () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.padding(context, 8)),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: Responsive.iconSize(context, 20), color: isDark ? Colors.white70 : Colors.grey[700]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: Responsive.fontSize(context, 12),
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF98FFD9),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, TextEditingController controller, IconData icon, Color primary, bool enabled, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 12),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: enabled ? primary : const Color(0xFF94A3B8), size: 20),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.transparent,
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 0), vertical: Responsive.padding(context, 12)),
            border: enabled
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  )
                : InputBorder.none,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticField(String label, String value, IconData icon, Color primary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 12),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, color: const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionOption(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.padding(context, 8)),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: Responsive.iconSize(context, 20), color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.fontSize(context, 12),
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.grey[500]),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isEmailPassword = authProvider.isEmailPasswordUser;
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        String? errorMessage;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Eliminar Cuenta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer y perderás todos tus datos.'),
                  const SizedBox(height: 16),
                  if (isEmailPassword) ...[
                    const Text('Para confirmar, ingresa tu contraseña:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Contraseña',
                      ),
                    ),
                  ] else ...[
                    const Text('Para confirmar, deberás volver a iniciar sesión con Google.', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          
                          bool canDelete = false;
                          
                          if (isEmailPassword) {
                            final pass = passwordController.text;
                            if (pass.isEmpty) {
                              setState(() {
                                errorMessage = 'La contraseña no puede estar vacía.';
                                isLoading = false;
                              });
                              return;
                            }
                            canDelete = await authProvider.verifyPassword(pass);
                            if (!canDelete) {
                              setState(() {
                                errorMessage = 'Contraseña incorrecta.';
                                isLoading = false;
                              });
                              return;
                            }
                          } else {
                            canDelete = await authProvider.signInWithGoogle();
                            if (!canDelete) {
                              setState(() {
                                errorMessage = 'No se pudo re-autenticar con Google.';
                                isLoading = false;
                              });
                              return;
                            }
                          }
                          
                          if (canDelete) {
                            final success = await authProvider.deleteAccount();
                            if (success && context.mounted) {
                               Navigator.pop(context);
                               GoRouter.of(context).go('/login');
                            } else if (context.mounted) {
                               setState(() {
                                 errorMessage = 'Error al eliminar la cuenta: ${authProvider.error ?? 'Error desconocido.'}';
                                 isLoading = false;
                               });
                            }
                          }
                        },
                  child: isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildLogoutButton(BuildContext context, Color primary) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => _showDeleteAccountDialog(context),
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          label: const Text('Eliminar cuenta', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 24), vertical: Responsive.padding(context, 12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
      onPressed: () async {
        final authProvider = context.read<AuthProvider>();
        final router = GoRouter.of(context);
        await authProvider.signOut();
        router.go('/login');
      },
      icon: const Icon(Icons.logout, color: Colors.red),
      label: Text(context.l10n.upSignOut, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 24), vertical: Responsive.padding(context, 12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
      ],
    );
  }
}
