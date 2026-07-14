import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/core/utils/responsive.dart';

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

  bool _isLoading = false;

  static const Map<String, List<String>> _elSalvadorDivipola = {
    'San Salvador': ['San Salvador', 'Soyapango', 'Mejicanos', 'Ilopango', 'Apopa', 'Ciudad Delgado', 'San Martín', 'Tonacatepeque', 'Cuscatancingo'],
    'La Libertad': ['Santa Tecla', 'Antiguo Cuscatlán', 'Colón', 'San Juan Opico', 'La Libertad', 'Quezaltepeque', 'Zaragoza'],
    'Santa Ana': ['Santa Ana', 'Chalchuapa', 'Metapán', 'Coatepeque', 'San Sebastián Salitrillo'],
    'San Miguel': ['San Miguel', 'El Tránsito', 'Ciudad Barrios', 'Chinameca'],
    'Sonsonate': ['Sonsonate', 'Izalco', 'Acajutla', 'Nahuizalco', 'Juayúa', 'Armenia'],
    'La Paz': ['Zacatecoluca', 'Olocuilta', 'San Luis Talpa', 'Santiago Nonualco'],
    'Ahuachapán': ['Ahuachapán', 'Atiquizaya', 'San Francisco Menéndez', 'Tacuba'],
    'Usulután': ['Usulután', 'Jiquilisco', 'Santiago de María', 'Puerto El Triunfo'],
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
    final user = context.read<UserSessionProvider>().userData;
    _nameController = TextEditingController(text: user?.nombreCompleto ?? '');
    _phoneController = TextEditingController(text: user?.telefono ?? '');
    _specialtyController = TextEditingController(text: user?.especialidad ?? '');
    
    // Limpieza de datos antiguos e inconsistentes de geografía (como Colombia)
    _selectedDept = user?.departamento;
    if (_selectedDept != null && !_elSalvadorDivipola.containsKey(_selectedDept)) {
      _selectedDept = null;
    }
    
    _selectedMuni = user?.municipio ?? user?.ubicacionMunicipio;
    if (_selectedMuni != null && (_selectedDept == null || !_elSalvadorDivipola[_selectedDept]!.contains(_selectedMuni))) {
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userSession = context.read<UserSessionProvider>();
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
                  fontSize: Responsive.fontSize(context, 16),
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
                                    fontSize: Responsive.fontSize(context, 22),
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 24)),
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
                                          padding: EdgeInsets.all(Responsive.padding(context, 12)),
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
                                                  fontSize: Responsive.fontSize(context, 18),
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                'Estos datos serán visibles en el directorio de talleres.',
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: Responsive.fontSize(context, 13),
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
                                    _buildDropdownField(
                                      label: 'Departamento',
                                      value: _selectedDept,
                                      items: _elSalvadorDivipola.keys.toList(),
                                      icon: Icons.map,
                                      colors: colors,
                                      isDark: isDark,
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedDept = val;
                                          _selectedMuni = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildDropdownField(
                                      label: 'Municipio',
                                      value: _selectedMuni,
                                      items: (_selectedDept == null ? [] : _elSalvadorDivipola[_selectedDept]) ?? [],
                                      icon: Icons.location_on,
                                      colors: colors,
                                      isDark: isDark,
                                      disabled: _selectedDept == null,
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedMuni = val;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildCoordinatesPicker(colors, isDark),
                                    const SizedBox(height: 20),
                                    _buildInputField(
                                      label: 'Teléfono de Contacto',
                                      controller: _phoneController,
                                      icon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                      hint: 'Ej: 7788-9900',
                                      colors: colors,
                                      isDark: isDark,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor, ingresa un número de teléfono';
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
                                            fontSize: Responsive.fontSize(context, 16),
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
      padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 32)),
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
              fontSize: Responsive.fontSize(context, 20),
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required AppColors colors,
    required bool isDark,
    required void Function(String?) onChanged,
    bool disabled = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: TextStyle(color: colors.textPrimary)),
            );
          }).toList(),
          onChanged: disabled ? null : onChanged,
          dropdownColor: colors.surfaceContainer,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
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
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinatesPicker(AppColors colors, bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.padding(context, 12)),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.map, color: primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación Geográfica',
                      style: GoogleFonts.montserrat(
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Permite calcular la distancia a la que te encuentras de tus clientes.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: Responsive.fontSize(context, 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_latitude != null && _longitude != null) ...[
            Container(
              padding: EdgeInsets.all(Responsive.padding(context, 16)),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coordenadas Registradas',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 14), color: colors.textPrimary),
                        ),
                        Text(
                          'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                          style: GoogleFonts.inter(fontSize: Responsive.fontSize(context, 12), color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(Responsive.padding(context, 16)),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: colors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aún no has registrado tus coordenadas de ubicación.',
                      style: GoogleFonts.inter(fontSize: Responsive.fontSize(context, 13), color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _obtenerUbicacionGPS,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Por GPS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _abrirSelectorMapa,
                  icon: const Icon(Icons.pin_drop),
                  label: const Text('En Mapa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _obtenerUbicacionGPS() async {
    setState(() => _isLoading = true);
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación GPS obtenida con éxito'),
            backgroundColor: Colors.green,
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
      if (mounted) setState(() => _isLoading = false);
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
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 16), color: colors.textPrimary),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _latitude = markerPos.latitude;
                      _longitude = markerPos.longitude;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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
            fontSize: Responsive.fontSize(context, 14),
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
