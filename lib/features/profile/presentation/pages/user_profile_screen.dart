import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/theme_provider.dart';

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
    final user = context.read<AuthProvider>().userData;
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
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.userData;
    if (currentUser == null) return;


    if (_imageFile != null) {
      // In a real app, we would upload to Firebase Storage here
      // For now, we'll simulate the update or just keep the local path if possible
      // (UserService has the upload method, but let's assume we use it)
      try {
        // This would require UserService, which we have.
        // We'll call updateProfile in AuthProvider which should handle the logic.
        // For simplicity in this demo, let's just update the name and photoUrl if uploaded.
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e')),
          );
        }
      }
    }

    final updatedUser = currentUser.copyWith(
      nombreCompleto: _nameController.text,
      // We don't usually allow email change easily in Firebase without re-auth
    );

    final success = await authProvider.updateProfile(updatedUser, imageFile: _imageFile);
    if (success) {
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
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

    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userData;
    final isLoading = authProvider.isLoading;

    if (isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Profile data not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(authProvider.error ?? 'Please complete your profile setup.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/profile_setup'),
                child: const Text('Setup Profile'),
              ),
              TextButton(
                onPressed: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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
                  padding: const EdgeInsets.all(24.0),
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
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              icon: isLoading ? null : const Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildAppBar(BuildContext context, Color primary, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          Text(
            'My Profile',
            style: GoogleFonts.inter(
              fontSize: 18,
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
                          child: Icon(Icons.person, size: 60, color: primary),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          user.nombreCompleto,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          user.rol,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(UserModel user, Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoField('Full Name', _nameController, Icons.person_outline, primary, _isEditing, isDark),
          const SizedBox(height: 24),
          _buildInfoField('Email Address', _emailController, Icons.email_outlined, primary, false, isDark), // Email usually not editable here
          const SizedBox(height: 24),
          _buildStaticField(
            'Member Since',
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
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeOption(
            context,
            'Dark Mode',
            'Switch between light and dark theme',
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
            'Follow System',
            'Use system default theme',
            Icons.settings_brightness_outlined,
            themeProvider.themeMode == ThemeMode.system,
            (value) {
              themeProvider.setThemeMode(value ? ThemeMode.system : (isDark ? ThemeMode.dark : ThemeMode.light));
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.grey[700]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
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
            fontSize: 12,
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: enabled ? primary : const Color(0xFF94A3B8), size: 20),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
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
            fontSize: 12,
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, Color primary) {
    return TextButton.icon(
      onPressed: () async {
        final authProvider = context.read<AuthProvider>();
        await authProvider.signOut();
        if (context.mounted) {
          context.go('/login');
        }
      },
      icon: const Icon(Icons.logout, color: Colors.red),
      label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
