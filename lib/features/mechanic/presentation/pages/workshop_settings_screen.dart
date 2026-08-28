import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:autodoc/core/constants/especialidades_taller.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';

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

  String? _selectedDept;
  String? _selectedMuni;
  double? _latitude;
  double? _longitude;

  /// Error de la sección de ubicación. No es un campo de `Form` (las
  /// coordenadas no se escriben, se fijan por GPS o mapa), así que se
  /// muestra a mano junto a los dos botones en vez de con un `validator`.
  String? _errorUbicacion;

  bool _isSaving = false;
  bool _isLocating = false;

  static const Map<String, List<String>> _elSalvadorDivipola = {
    'San Salvador': [
      'San Salvador',
      'Soyapango',
      'Mejicanos',
      'Ilopango',
      'Apopa',
      'Ciudad Delgado',
      'San Martín',
      'Tonacatepeque',
      'Cuscatancingo',
    ],
    'La Libertad': [
      'Santa Tecla',
      'Antiguo Cuscatlán',
      'Colón',
      'San Juan Opico',
      'La Libertad',
      'Quezaltepeque',
      'Zaragoza',
    ],
    'Santa Ana': [
      'Santa Ana',
      'Chalchuapa',
      'Metapán',
      'Coatepeque',
      'San Sebastián Salitrillo',
    ],
    'San Miguel': ['San Miguel', 'El Tránsito', 'Ciudad Barrios', 'Chinameca'],
    'Sonsonate': [
      'Sonsonate',
      'Izalco',
      'Acajutla',
      'Nahuizalco',
      'Juayúa',
      'Armenia',
    ],
    'La Paz': [
      'Zacatecoluca',
      'Olocuilta',
      'San Luis Talpa',
      'Santiago Nonualco',
    ],
    'Ahuachapán': [
      'Ahuachapán',
      'Atiquizaya',
      'San Francisco Menéndez',
      'Tacuba',
    ],
    'Usulután': [
      'Usulután',
      'Jiquilisco',
      'Santiago de María',
      'Puerto El Triunfo',
    ],
  };

  String _formatPhoneNumber(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('503') && digits.length > 8) {
      digits = digits.substring(3);
    }
    if (digits.length > 8) {
      digits = digits.substring(digits.length - 8);
    }
    if (digits.length == 8) {
      return '+503 ${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return input;
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProfileProvider>().userData;
    _nameController = TextEditingController(text: user?.nombreCompleto ?? '');
    _phoneController = TextEditingController(text: user?.telefono ?? '');
    _specialtyController = TextEditingController(
      text: user?.especialidad ?? '',
    );
    // Limpieza de valores antiguos de especialidad en texto libre que ya no
    // están en la lista fija: sin esto, un taller con un valor legacy pasa
    // el chequeo de "requerido" sin nunca elegir una opción válida del
    // dropdown y el valor obsoleto se vuelve a guardar sin normalizar.
    if (!especialidadesTaller.contains(_specialtyController.text)) {
      _specialtyController.text = '';
    }

    // Limpieza de datos antiguos e inconsistentes de geografía (como Colombia)
    _selectedDept = user?.departamento;
    if (_selectedDept != null &&
        !_elSalvadorDivipola.containsKey(_selectedDept)) {
      _selectedDept = null;
    }

    _selectedMuni = user?.municipio ?? user?.ubicacionMunicipio;
    if (_selectedMuni != null &&
        (_selectedDept == null ||
            !_elSalvadorDivipola[_selectedDept]!.contains(_selectedMuni))) {
      _selectedMuni = null;
    }

    _latitude = user?.latitud;
    _longitude = user?.longitud;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final formValid = _formKey.currentState!.validate();

    setState(() {
      _errorUbicacion = (_latitude == null || _longitude == null)
          ? 'Registra tu ubicación para que los clientes te encuentren'
          : null;
    });

    if (!formValid || _errorUbicacion != null) return;

    setState(() => _isSaving = true);

    try {
      final userSession = context.read<UserProfileProvider>();
      final currentUser = userSession.userData;

      if (currentUser != null) {
        final rawPhone = _phoneController.text.trim();
        final formattedPhone = _formatPhoneNumber(rawPhone);

        final updatedUser = currentUser.copyWith(
          nombreCompleto: _nameController.text.trim(),
          telefono: formattedPhone,
          especialidad: _specialtyController.text.trim(),
          ubicacionMunicipio: _selectedMuni ?? '',
          departamento: _selectedDept,
          municipio: _selectedMuni,
          latitud: _latitude,
          longitud: _longitude,
        );

        final success = await userSession.updateProfile(updatedUser);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Perfil de taller actualizado exitosamente'),
              backgroundColor: context.appColors.secondary,
            ),
          );
        } else {
          throw userSession.error ?? 'Error desconocido al actualizar perfil';
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return MechanicScaffold(
      title: 'Configuración',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: AppPageBody(
          maxWidth: AppBreakpoints.of(context).isAtLeastExpanded
              ? AppBreakpoints.maxContentWidth
              : AppBreakpoints.maxFormWidth,
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dosColumnas = AppBreakpoints.fromWidth(
                  constraints.maxWidth,
                ).isAtLeastExpanded;
                final infoPublica = _InfoPublicaSection(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  specialtyController: _specialtyController,
                  selectedDept: _selectedDept,
                  selectedMuni: _selectedMuni,
                  divipola: _elSalvadorDivipola,
                  colors: colors,
                  onSpecialtyChanged: (val) {
                    setState(() => _specialtyController.text = val ?? '');
                  },
                  onDeptChanged: (val) {
                    setState(() {
                      _selectedDept = val;
                      _selectedMuni = null;
                    });
                  },
                  onMuniChanged: (val) {
                    setState(() => _selectedMuni = val);
                  },
                );
                final ubicacion = _UbicacionSection(
                  colors: colors,
                  latitude: _latitude,
                  longitude: _longitude,
                  errorUbicacion: _errorUbicacion,
                  isLocating: _isLocating,
                  onGps: _obtenerUbicacionGPS,
                  onMapa: _abrirSelectorMapa,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dosColumnas)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: infoPublica),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(child: ubicacion),
                        ],
                      )
                    else ...[
                      infoPublica,
                      const SizedBox(height: AppSpacing.base),
                      ubicacion,
                    ],
                    const SizedBox(height: AppSpacing.base),
                    AppButton(
                      text: 'Guardar Cambios',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveSettings,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _obtenerUbicacionGPS() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permiso de ubicación denegado';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Los permisos de ubicación están denegados permanentemente';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _errorUbicacion = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ubicación GPS obtenida con éxito'),
            backgroundColor: context.appColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error GPS: $e'),
            backgroundColor: context.appColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _abrirSelectorMapa() {
    final colors = context.appColors;
    LatLng? selectedLatLng = _latitude != null && _longitude != null
        ? LatLng(_latitude!, _longitude!)
        : const LatLng(13.6929, -89.2182); // San Salvador, El Salvador

    showDialog(
      context: context,
      builder: (ctx) {
        LatLng markerPos = selectedLatLng;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              title: Text(
                'Toca en tu ubicación exacta',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              content: AppDialogContent(
                maxWidth: 640,
                child: SizedBox(
                  height: AppBreakpoints.of(context).isCompact ? 280 : 400,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Semantics(
                      label:
                          'Mapa para elegir la ubicación del taller. Toca para marcar el punto.',
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: markerPos,
                          zoom: 14,
                        ),
                        onTap: (latLng) {
                          setDialogState(() {
                            markerPos = latLng;
                          });
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('workshop_selected'),
                            position: markerPos,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                AppButton(
                  text: 'Cancelar',
                  type: AppButtonType.text,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(ctx),
                ),
                AppButton(
                  text: 'Confirmar',
                  size: AppButtonSize.small,
                  onPressed: () {
                    setState(() {
                      _latitude = markerPos.latitude;
                      _longitude = markerPos.longitude;
                      _errorUbicacion = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Columna izquierda: nombre, especialidad, departamento, municipio,
/// teléfono. Datos visibles en el directorio de talleres.
class _InfoPublicaSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController specialtyController;
  final String? selectedDept;
  final String? selectedMuni;
  final Map<String, List<String>> divipola;
  final AppColors colors;
  final void Function(String?) onSpecialtyChanged;
  final void Function(String?) onDeptChanged;
  final void Function(String?) onMuniChanged;

  const _InfoPublicaSection({
    required this.nameController,
    required this.phoneController,
    required this.specialtyController,
    required this.selectedDept,
    required this.selectedMuni,
    required this.divipola,
    required this.colors,
    required this.onSpecialtyChanged,
    required this.onDeptChanged,
    required this.onMuniChanged,
  });

  @override
  Widget build(BuildContext context) {
    final municipios = selectedDept == null
        ? const <String>[]
        : (divipola[selectedDept] ?? const <String>[]);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding izquierdo igual al de la etiqueta de AppTextField
          // (AppSpacing.xs): sin él, el encabezado de la sección y la
          // etiqueta del primer campo no comparten el mismo borde izquierdo.
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: AppSectionHeader(
              title: 'Información Pública',
              subtitle:
                  'Estos datos serán visibles en el directorio de talleres.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Nombre del Taller',
            controller: nameController,
            prefixIcon: const Icon(Icons.business),
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _DropdownField(
            label: 'Especialidad',
            value: especialidadesTaller.contains(specialtyController.text)
                ? specialtyController.text
                : null,
            items: especialidadesTaller,
            icon: Icons.build_circle,
            colors: colors,
            onChanged: onSpecialtyChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Departamento y Municipio comparten fila: son dos mitades del
          // mismo dato geográfico y juntarlos ahorra el alto de un campo
          // completo, que es lo que permite que "Guardar Cambios" quepa en
          // la pantalla de un teléfono sin desplazamiento.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Departamento',
                  value: selectedDept,
                  items: divipola.keys.toList(),
                  icon: Icons.map,
                  colors: colors,
                  onChanged: onDeptChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DropdownField(
                  label: 'Municipio',
                  value: selectedMuni,
                  items: municipios,
                  icon: Icons.location_on,
                  colors: colors,
                  disabled: selectedDept == null,
                  onChanged: onMuniChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Teléfono de Contacto (opcional)',
            controller: phoneController,
            prefixIcon: const Icon(Icons.phone),
            keyboardType: TextInputType.phone,
            hintText: 'Ej: 7788-9900',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null; // No es obligatorio
              }
              final digits = value.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 8) {
                return 'El número debe tener al menos 8 dígitos';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

/// Columna derecha: ubicación geográfica (GPS o mapa).
class _UbicacionSection extends StatelessWidget {
  final AppColors colors;
  final double? latitude;
  final double? longitude;
  final String? errorUbicacion;
  final bool isLocating;
  final VoidCallback onGps;
  final VoidCallback onMapa;

  const _UbicacionSection({
    required this.colors,
    required this.latitude,
    required this.longitude,
    required this.errorUbicacion,
    required this.isLocating,
    required this.onGps,
    required this.onMapa,
  });

  @override
  Widget build(BuildContext context) {
    final tieneCoordenadas = latitude != null && longitude != null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: AppSectionHeader(
              title: 'Ubicación Geográfica',
              subtitle:
                  'Permite calcular la distancia a la que te encuentras de tus clientes.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tieneCoordenadas)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: colors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coordenadas Registradas',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Lat: ${latitude!.toStringAsFixed(6)}, Lng: ${longitude!.toStringAsFixed(6)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: colors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Aún no has registrado tus coordenadas de ubicación.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Por GPS',
                  size: AppButtonSize.small,
                  isLoading: isLocating,
                  icon: const Icon(Icons.gps_fixed),
                  onPressed: isLocating ? null : onGps,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  text: 'En Mapa',
                  type: AppButtonType.secondary,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.pin_drop),
                  onPressed: onMapa,
                ),
              ),
            ],
          ),
          if (errorUbicacion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorUbicacion!,
              style: AppTextStyles.bodySmall.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// No hay `AppDropdownField` en el design system: se conserva la
/// reimplementación a mano, pero tokenizada.
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final AppColors colors;
  final void Function(String?) onChanged;
  final bool disabled;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.colors,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.4)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: colors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: disabled ? null : onChanged,
          dropdownColor: colors.surfaceContainer,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: colors.textSecondary),
            filled: true,
            fillColor: colors.surfaceContainer,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
