import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart'
    as app_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/providers/session_reset.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
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

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    final auth = context.read<app_auth.AuthProvider>();
    clearSessionFrom(context);
    await auth.signOut();
    router.go('/login');
  }

  Future<void> _pickPhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  static int _ageAt(DateTime birthDate, DateTime now) {
    int age = now.year - birthDate.year;
    final hasHadBirthdayThisYear =
        (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = appColors.primary;
    final secondaryColor = appColors.secondary;

    final windowClass = AppBreakpoints.of(context);

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
              titleSpacing: AppSpacing.base,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car, color: primaryColor, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'AutoDoc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // Antes: TextButton.icon + una columna con «PASO 1 DE 1»
                // y una barra al 100 %. Entre los dos consumian ~250 px de
                // los 320 y dejaban al titulo sin sitio. No habia paso 2.
                IconButton(
                  tooltip: 'Salir',
                  onPressed: _signOut,
                  icon: Icon(Icons.logout, color: appColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
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
              padding: EdgeInsets.fromLTRB(
                AppBreakpoints.gutter(windowClass),
                // Con `extendBodyBehindAppBar: true`, `SafeArea` ya inserta
                // el alto de la `AppBar` automaticamente (Scaffold ajusta el
                // `MediaQuery.padding.top` del body para que la evite);
                // antes esto usaba 24 fijos y el `SafeArea` ni se enteraba
                // de la barra, asi que el titulo arrancaba debajo de la
                // barra translucida. Solo hace falta un respiro adicional.
                AppSpacing.xl,
                AppBreakpoints.gutter(windowClass),
                120,
              ),
              child: Center(
                child: ConstrainedBox(
                  key: const ValueKey('setup-form'),
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxFormWidth,
                  ),
                  child: Column(
                    children: [
                      // Main Glass Panel Container
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? appColors.surfaceContainer.withValues(
                                  alpha: 0.75,
                                )
                              : appColors.surfaceContainer.withValues(
                                  alpha: 0.85,
                                ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDarkMode
                                ? appColors.outline.withValues(alpha: 0.5)
                                : appColors.outline.withValues(alpha: 0.3),
                          ),
                          boxShadow: isDarkMode
                              ? AppShadows.darkLg
                              : AppShadows.lightLg,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Padding(
                              padding: EdgeInsets.all(
                                Responsive.padding(context, 32.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                        '¡Bienvenido a AutoDoc!',
                                        style: AppTextStyles.headlineSmall
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: appColors.textPrimary,
                                              letterSpacing: -0.5,
                                            ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 400.ms)
                                      .slideY(begin: -0.1, end: 0),
                                  const SizedBox(height: 8),

                                  // Subtitle with high contrast
                                  Text(
                                    'Configura tu perfil para obtener diagnósticos personalizados y alertas precisas para tu vehículo.',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: appColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ).animate().fadeIn(
                                    delay: 100.ms,
                                    duration: 400.ms,
                                  ),
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
                                            color: primaryColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            border: Border.all(
                                              color: primaryColor.withValues(
                                                alpha: 0.6,
                                              ),
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 16,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: _imageFile != null
                                                ? FutureBuilder<List<int>>(
                                                    future: _imageFile!
                                                        .readAsBytes()
                                                        .then(
                                                          (b) => b.toList(),
                                                        ),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        return Image.memory(
                                                          Uint8List.fromList(
                                                            snapshot.data!,
                                                          ),
                                                          fit: BoxFit.cover,
                                                          width: 104,
                                                          height: 104,
                                                        );
                                                      }
                                                      return Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  primaryColor,
                                                              strokeWidth: 2,
                                                            ),
                                                      );
                                                    },
                                                  )
                                                : Icon(
                                                    Icons.person_rounded,
                                                    size: Responsive.iconSize(
                                                      context,
                                                      54,
                                                    ),
                                                    color: primaryColor,
                                                  ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Tooltip(
                                            message: 'Elegir foto de perfil',
                                            child: InkWell(
                                              key: const ValueKey(
                                                'setup-pick-photo',
                                              ),
                                              customBorder:
                                                  const CircleBorder(),
                                              onTap: _pickPhoto,
                                              child: Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: appColors.surface,
                                                    width: 2,
                                                  ),
                                                  boxShadow: AppShadows.darkSm,
                                                ),
                                                child: Icon(
                                                  Icons.camera_alt_rounded,
                                                  color: appColors.onPrimary,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().scale(
                                    delay: 150.ms,
                                    duration: 400.ms,
                                    curve: Curves.easeOutBack,
                                  ),
                                  const SizedBox(height: 32),

                                  // Full Name Label
                                  Text(
                                    'NOMBRE COMPLETO',
                                    style: AppTextStyles.labelSmall.copyWith(
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
                                          ? appColors.surfaceVariant.withValues(
                                              alpha: 0.6,
                                            )
                                          : appColors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: appColors.outline.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _nameController,
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: appColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ej. Juan Pérez',
                                        hintStyle: AppTextStyles.bodyLarge
                                            .copyWith(
                                              color: appColors.textSecondary,
                                            ),
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                          color: appColors.textSecondary,
                                          size: Responsive.iconSize(
                                            context,
                                            20,
                                          ),
                                        ),
                                        filled: false,
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Birth Date Label
                                  Text(
                                    'FECHA DE NACIMIENTO',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: appColors.textSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Birth Date Picker Field
                                  InkWell(
                                    key: const ValueKey('setup-birth-date'),
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _pickBirthDate,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? appColors.surfaceVariant
                                                  .withValues(alpha: 0.6)
                                            : appColors.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: appColors.outline.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.cake_outlined,
                                            color: appColors.textSecondary,
                                            size: Responsive.iconSize(
                                              context,
                                              20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _birthDate != null
                                                  ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                                                  : 'Selecciona tu fecha de nacimiento',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.bodyLarge
                                                  .copyWith(
                                                    fontWeight:
                                                        _birthDate != null
                                                        ? FontWeight.w500
                                                        : FontWeight.normal,
                                                    color: _birthDate != null
                                                        ? appColors.textPrimary
                                                        : appColors
                                                              .textSecondary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Role Selection Label
                                  Text(
                                    'SELECCIONA TU ROL',
                                    style: AppTextStyles.labelSmall.copyWith(
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
                                          key: const ValueKey(
                                            'setup-role-propietario',
                                          ),
                                          title: 'Propietario',
                                          icon: Icons.person_outline_rounded,
                                          isSelected:
                                              _selectedRole == 'Propietario',
                                          onTap: () => setState(
                                            () => _selectedRole = 'Propietario',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _buildRoleCard(
                                          key: const ValueKey(
                                            'setup-role-mecanico',
                                          ),
                                          title: 'Mecánico',
                                          icon: Icons.build_circle_outlined,
                                          isSelected:
                                              _selectedRole == 'Mecanico',
                                          onTap: () => setState(
                                            () => _selectedRole = 'Mecanico',
                                          ),
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
                                        color: primaryColor.withValues(
                                          alpha: isDarkMode ? 0.12 : 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: primaryColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color:
                                                        appColors.textPrimary,
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
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: appColors.textSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Maintenance Notifications Switch Row
                                  Container(
                                    padding: EdgeInsets.all(
                                      Responsive.padding(context, 16),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? appColors.surfaceVariant.withValues(
                                              alpha: 0.5,
                                            )
                                          : appColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: appColors.outline.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(
                                              alpha: 0.15,
                                            ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Notificaciones de mantenimiento',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          appColors.textPrimary,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Alertas sobre cambios de aceite, frenos y revisiones.',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: appColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _notificationsEnabled,
                                          onChanged: (val) => setState(
                                            () => _notificationsEnabled = val,
                                          ),
                                          activeThumbColor: primaryColor,
                                          activeTrackColor: primaryColor
                                              .withValues(alpha: 0.3),
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
          ),
        ],
      ),
      // `bottomNavigationBar`, no `bottomSheet`: este ultimo flota SOBRE el
      // body sin reservarle espacio, asi que el contenido final del
      // `SingleChildScrollView` (las tarjetas de rol en telefonos bajos)
      // queda parcial o totalmente detras del boton de envio y no se puede
      // pulsar.
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 24),
          vertical: Responsive.padding(context, 16),
        ),
        decoration: BoxDecoration(
          color: appColors.surface,
          border: Border(
            top: BorderSide(color: appColors.outline.withValues(alpha: 0.3)),
          ),
          boxShadow: isDarkMode ? AppShadows.darkMd : AppShadows.lightMd,
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: AppButton(
              text: _isLoading ? 'Guardando...' : 'Finalizar Configuración',
              isLoading: _isLoading,
              icon: _isLoading ? null : const Icon(Icons.arrow_forward_rounded),
              onPressed: _isLoading ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final appColors = context.appColors;
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

    final birthDate = _birthDate;
    if (birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, ingresa tu fecha de nacimiento'),
          backgroundColor: appColors.error,
        ),
      );
      return;
    }

    if (_ageAt(birthDate, DateTime.now()) < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Debes ser mayor de 18 años para usar AutoDoc'),
          backgroundColor: appColors.error,
        ),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error: Sesión no encontrada. Vuelve a iniciar sesión.',
          ),
          backgroundColor: appColors.error,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Un taller nace SIEMPRE 'pendiente': no puede operar hasta que un
      // administrador lo apruebe (ver AdminService.aprobarUsuario). Es lo que
      // exige `firestore.rules` para el create de rol 'Mecanico', y lo que
      // mantiene la cuenta retenida en /mechanic_pending — 'pendiente' no está
      // en `estadosMecanicoAprobado`. Un propietario conserva el 'activo' por
      // defecto de UserModel: no necesita aprobación de nadie.
      final esMecanico = isMechanicRole(_selectedRole);

      UserModel userModel = UserModel(
        idUsuario: user.uid,
        nombreCompleto: name,
        correo: user.email ?? '',
        rol: _selectedRole,
        fechaRegistro: DateTime.now(),
        fechaNacimiento: birthDate,
        estado: esMecanico ? 'pendiente' : 'activo',
      );

      final success = await profileProvider.updateProfile(
        userModel,
        imageFile: _imageFile,
        isNewUser: true,
      );

      if (success) {
        await user.updateDisplayName(name);
        await user.reload();

        if (!mounted) return;
        // El taller recién creado está 'pendiente', así que /mechanic_dashboard
        // sería rebotado por resolveRedirect() a /mechanic_pending igualmente.
        // Navegar ahí directamente evita el salto visible y deja claro al
        // usuario que su cuenta está en revisión.
        context.go(esMecanico ? '/mechanic_pending' : '/dashboard');
      } else {
        throw profileProvider.error ?? 'Error desconocido al guardar el perfil';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: appColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRoleCard({
    required Key key,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final appColors = context.appColors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = appColors.primary;

    return Semantics(
      key: key,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: AppMotion.transformDuration(context, AppMotion.press),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.1)
                : (isDarkMode
                      ? appColors.surfaceVariant.withValues(alpha: 0.4)
                      : appColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : appColors.outline.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El color NO es el unico portador del estado: ademas del
              // borde grueso y el relleno, un check explicito.
              Icon(
                isSelected ? Icons.check_circle : icon,
                color: isSelected ? primaryColor : appColors.textSecondary,
                size: 34,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? appColors.textPrimary
                      : appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
