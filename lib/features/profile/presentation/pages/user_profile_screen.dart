import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/session_reset.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
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
  XFile? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProfileProvider>().userData;
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
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _saveProfile() async {
    final sessionProvider = context.read<UserProfileProvider>();
    final currentUser = sessionProvider.userData;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(
      nombreCompleto: _nameController.text,
    );

    final success = await sessionProvider.updateProfile(
      updatedUser,
      imageFile: _imageFile,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.upProfileUpdatedSuccess)),
      );
    } else if (sessionProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.upErrorUploadingImage(sessionProvider.error!),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPurple = colors.primary;
    final textColor = colors.textPrimary;
    final isWide = AppBreakpoints.of(context).isAtLeastExpanded;

    final sessionProvider = context.watch<UserProfileProvider>();
    final user = sessionProvider.userData;
    final isLoading = sessionProvider.isLoading;

    if (isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBreakpoints.of(context).isAtLeastExpanded
            ? null
            : AppBar(title: Text(context.l10n.upProfileTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: Responsive.iconSize(context, 64),
                color: colors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.upProfileDataNotFound,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sessionProvider.error ?? context.l10n.upPleaseCompleteSetup,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                text: context.l10n.upSetupProfile,
                size: AppButtonSize.medium,
                onPressed: () => context.go('/profile_setup'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: context.l10n.upSignOut,
                type: AppButtonType.text,
                size: AppButtonSize.small,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final auth = context.read<AuthProvider>();
                  clearSessionFrom(context);
                  await auth.signOut();
                  router.go('/login');
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // La flecha de atras solo tiene sentido si hay algo que desapilar.
        // `/user_profile` es una pestana del ShellRoute: no lo hay.
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.upMyProfile,
          style: AppTextStyles.titleLarge.copyWith(color: textColor),
        ),
        actions: [
          IconButton(
            key: const ValueKey('profile-edit-toggle'),
            // upEditProfile no existe en el ARB (la fase prohibe anadir
            // claves): literal en espanol, mejor que ningun tooltip.
            tooltip: _isEditing ? context.l10n.upCancel : 'Editar perfil',
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit_outlined,
              color: primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceVariant, colors.surface],
          ),
        ),
        child: SafeArea(child: _buildBody(user, colors, isDark, isWide)),
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              key: const ValueKey('profile-save'),
              onPressed: isLoading ? null : _saveProfile,
              backgroundColor: primaryPurple,
              label: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: colors.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      context.l10n.upSaveChanges,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimary,
                      ),
                    ),
              icon: isLoading
                  ? null
                  : Icon(Icons.check, color: colors.onPrimary),
            )
          : null,
    );
  }

  /// Compone cabecera + contenido: una columna por debajo de `expanded`, dos
  /// a partir de ahi (cabecera fija a la izquierda, contenido con scroll
  /// propio a la derecha), acotado a `maxContentWidth`.
  Widget _buildBody(
    UserModel user,
    AppColors colors,
    bool isDark,
    bool isWide,
  ) {
    final header = _buildProfileHeader(
      user,
      colors.primary,
      colors.textPrimary,
    );
    final details = Column(
      children: [
        _buildInfoSection(user, colors.primary, isDark),
        const SizedBox(height: AppSpacing.xl),
        _buildSettingsSection(context, colors.primary, isDark),
        const SizedBox(height: AppSpacing.xxl),
        _buildAccountActions(context, colors),
      ],
    );

    if (!isWide) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(
          AppBreakpoints.gutter(AppBreakpoints.of(context)),
        ),
        child: Column(
          children: [
            header,
            const SizedBox(height: AppSpacing.xxl),
            details,
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.maxContentWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La cabecera queda fija: es identidad, no contenido.
            Expanded(
              flex: 2,
              child: Padding(
                key: const ValueKey('profile-side-column'),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: header,
              ),
            ),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                key: const ValueKey('profile-main-column'),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: details,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, Color primary, Color textColor) {
    final colors = context.appColors;
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 4),
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
                    ? FutureBuilder<List<int>>(
                        future: _imageFile!.readAsBytes().then(
                          (b) => b.toList(),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              Uint8List.fromList(snapshot.data!),
                              fit: BoxFit.cover,
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      )
                    : CachedNetworkImage(
                        imageUrl: user.fotoPerfilUrl ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: colors.surfaceVariant),
                        errorWidget: (context, url, error) => Container(
                          color: primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person,
                            size: Responsive.iconSize(context, 60),
                            color: primary,
                          ),
                        ),
                      ),
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Tooltip(
                  message: 'Elegir foto de perfil',
                  child: InkWell(
                    key: const ValueKey('profile-photo-camera'),
                    customBorder: const CircleBorder(),
                    onTap: _pickImage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                        boxShadow: AppShadows.darkSm,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: colors.onPrimary,
                        size: Responsive.iconSize(context, 20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          user.nombreCompleto,
          style: AppTextStyles.headlineSmall.copyWith(
            fontSize: Responsive.fontSize(context, 24),
            color: textColor,
          ),
        ),
        Text(
          user.rol,
          style: AppTextStyles.titleSmall.copyWith(
            fontSize: Responsive.fontSize(context, 14),
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(UserModel user, Color primary, bool isDark) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      decoration: _cardDecoration(colors, isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            key: const ValueKey('profile-name-field'),
            label: context.l10n.upFullName,
            controller: _nameController,
            enabled: _isEditing,
            prefixIcon: Icon(Icons.person_outline, color: colors.primary),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            key: const ValueKey('profile-email-field'),
            label: context.l10n.upEmailAddress,
            controller: _emailController,
            enabled: false,
            prefixIcon: Icon(Icons.email_outlined, color: colors.textSecondary),
          ), // Email usually not editable here
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

  BoxDecoration _cardDecoration(AppColors colors, bool isDark) {
    return BoxDecoration(
      color: colors.surfaceContainer.withValues(alpha: isDark ? 0.6 : 0.85),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      boxShadow: isDark ? AppShadows.darkSm : AppShadows.lightSm,
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    Color primary,
    bool isDark,
  ) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      decoration: _cardDecoration(colors, isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.upSettings,
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: primary,
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
              themeProvider.setThemeMode(
                value ? ThemeMode.dark : ThemeMode.light,
              );
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
              themeProvider.setThemeMode(
                value
                    ? ThemeMode.system
                    : (isDark ? ThemeMode.dark : ThemeMode.light),
              );
            },
            isDark,
          ),
          const Divider(height: 32),
          _buildThemeOption(
            context,
            context.l10n.upLanguage,
            context.l10n.upLanguageDesc,
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
            context.l10n.upAbout,
            context.l10n.upAboutDesc,
            Icons.info_outline,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
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
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.padding(context, 8)),
          decoration: BoxDecoration(
            color: isDark
                ? colors.textPrimary.withValues(alpha: 0.1)
                : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: Responsive.iconSize(context, 20),
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: Responsive.fontSize(context, 16),
                  color: colors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: Responsive.fontSize(context, 12),
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.onPrimary,
          activeTrackColor: colors.primary,
        ),
      ],
    );
  }

  Widget _buildStaticField(
    String label,
    String value,
    IconData icon,
    Color primary,
    bool isDark,
  ) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontSize: Responsive.fontSize(context, 12),
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, color: colors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              value,
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: Responsive.fontSize(context, 16),
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.padding(context, 8)),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.textPrimary.withValues(alpha: 0.1)
                  : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: Responsive.iconSize(context, 20),
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: Responsive.fontSize(context, 16),
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: Responsive.fontSize(context, 12),
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: colors.textSecondary),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final colors = context.appColors;
    final isEmailPassword = authProvider.isEmailPasswordUser;
    final passwordController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          bool isLoading = false;
          String? errorMessage;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(context.l10n.upDeleteAccountTitle),
                content: AppDialogContent(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.upDeleteAccountConfirm),
                      const SizedBox(height: 16),
                      if (isEmailPassword) ...[
                        Text(
                          context.l10n.upEnterPasswordConfirm,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: passwordController,
                          label: context.l10n.upPasswordLabel,
                          obscureText: true,
                          obscureToggle: true,
                          enabled: !isLoading,
                        ),
                      ] else ...[
                        Text(
                          context.l10n.upGoogleReauthConfirm,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  AppButton(
                    key: const ValueKey('profile-delete-cancel'),
                    text: context.l10n.upCancel,
                    type: AppButtonType.text,
                    size: AppButtonSize.small,
                    onPressed: isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  AppButton(
                    text: context.l10n.upDelete,
                    type: AppButtonType.danger,
                    size: AppButtonSize.small,
                    isLoading: isLoading,
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
                                  errorMessage = context.l10n.upPasswordEmpty;
                                  isLoading = false;
                                });
                                return;
                              }
                              canDelete = await authProvider.verifyPassword(
                                pass,
                              );
                              if (!canDelete) {
                                setState(() {
                                  errorMessage =
                                      context.l10n.upPasswordIncorrect;
                                  isLoading = false;
                                });
                                return;
                              }
                            } else {
                              canDelete = await authProvider.signInWithGoogle();
                              if (!canDelete) {
                                setState(() {
                                  errorMessage =
                                      context.l10n.upGoogleReauthFailed;
                                  isLoading = false;
                                });
                                return;
                              }
                            }

                            if (canDelete) {
                              final success = await authProvider
                                  .deleteAccount();
                              if (success && context.mounted) {
                                Navigator.of(context).pop();
                                GoRouter.of(context).go('/login');
                              } else if (context.mounted) {
                                setState(() {
                                  errorMessage = context.l10n
                                      .upDeleteAccountError(
                                        authProvider.error ?? 'Unknown error',
                                      );
                                  isLoading = false;
                                });
                              }
                            }
                          },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Antes no se liberaba nunca: una fuga por cada apertura del dialogo.
      passwordController.dispose();
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);
    clearSessionFrom(context);
    await authProvider.signOut();
    router.go('/login');
  }

  /// Las dos acciones destructivas, diferenciadas: cerrar sesion no es
  /// destructivo (sube a `AppButton` secundario), borrar la cuenta si lo es
  /// y se queda como enlace en color de error, debajo y con menos peso.
  Widget _buildAccountActions(BuildContext context, AppColors colors) {
    return Column(
      children: [
        AppButton(
          text: context.l10n.upSignOut,
          type: AppButtonType.secondary,
          icon: const Icon(Icons.logout),
          onPressed: () => _signOut(context),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: const ValueKey('profile-delete-account'),
          text: context.l10n.upDeleteAccount,
          type: AppButtonType.danger,
          size: AppButtonSize.small,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteAccountDialog(context),
        ),
      ],
    );
  }
}
