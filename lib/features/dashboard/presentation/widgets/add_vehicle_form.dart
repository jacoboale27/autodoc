import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/utils/plate_formatter.dart';
import '../../../../core/models/nhtsa_models.dart';
import '../../../../core/services/vehicle_api_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AddVehicleForm extends StatefulWidget {
  final Function(VehicleModel) onFinish;
  final Color primaryColor;

  const AddVehicleForm({
    super.key,
    required this.onFinish,
    required this.primaryColor,
  });

  @override
  State<AddVehicleForm> createState() => _AddVehicleFormState();
}

class _AddVehicleFormState extends State<AddVehicleForm> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isFinishing = false; // Nueva variable para controlar el estado final

  // Selection data
  String? _selectedBrand;
  String? _selectedModel;
  String _searchQuery = '';
  String _brandSearchQuery = '';

  static const List<String> _popularMakes = [
    'Toyota',
    'Nissan',
    'Honda',
    'Hyundai',
    'Kia',
    'Chevrolet',
    'Ford',
    'Mazda',
    'Volkswagen',
    'Renault',
    'Peugeot',
    'Suzuki',
    'Mitsubishi',
    'Subaru',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Jeep',
    'Fiat',
    'Dodge',
    'Volvo',
    'Lexus',
    'Porsche',
    'Land Rover',
    'Jaguar',
    'Mini',
    'Alfa Romeo',
    'Acura',
    'Infiniti',
    'Lincoln',
    'Buick',
    'Cadillac',
    'Chrysler',
    'GMC',
    'Ram',
    'Tesla',
    'Seat',
    'Skoda',
    'Citroen',
    'Chery',
    'MG',
    'JAC',
    'Changan',
    'Geely',
    'Great Wall',
    'BYD',
    'Haval',
    'SsangYong',
    'Isuzu',
    'Aston Martin',
    'Ferrari',
    'Lamborghini',
    'Maserati',
    'McLaren',
    'Bentley',
    'Rolls Royce',
    'Genesis',
    'Smart',
  ];

  // API Data
  final VehicleApiService _apiService = VehicleApiService();
  List<CarMake> _allMakes = [];
  List<CarModel> _makeModels = [];
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  String? _makesError;
  String? _modelsError;

  // Controllers for final step
  final _placaController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  final _kilometrajeController = TextEditingController();
  DateTime? _vencimientoTarjeta;
  DateTime? _vencimientoSoat;

  // Errores de año/color/kilometraje señalados en el propio campo. Antes se
  // avisaban con un snackbar, que desaparece solo y no indica qué campo lo
  // causó; peor aún, el formulario vive dentro de un modal bottom sheet a
  // pantalla completa (`isScrollControlled: true`), así que el snackbar lo
  // pinta el Scaffold DEBAJO del sheet y no se ve en absoluto: el botón
  // "Finalizar Registro" parecía no hacer nada.
  String? _anioError;
  String? _colorError;
  String? _kilometrajeError;

  // Tipo de placa elegido por el usuario. Decide la letra inicial: el VMT
  // usa una distinta por clase de vehículo (P particular, M moto, C carga,
  // A alquiler), así que no se puede dar por hecha la P.
  TipoPlaca _tipoPlaca = TipoPlaca.particular;

  // El paso de detalles scrollea y el botón queda al final: si el campo
  // inválido es la placa (arriba del todo), marcarlo no basta, hay que
  // traerlo a la vista o el usuario tampoco ve el error.
  final _placaFieldKey = GlobalKey();
  final _anioFieldKey = GlobalKey();
  final _colorFieldKey = GlobalKey();
  final _kilometrajeFieldKey = GlobalKey();

  /// Cambia el tipo de placa conservando el correlativo ya tecleado: solo se
  /// reescribe la letra inicial. El prefijo anterior se recorta a mano antes
  /// de recomponer porque `A` y `C` son además dígitos hexadecimales válidos,
  /// y dejarlos pasar los colaría dentro del correlativo.
  void _cambiarTipoPlaca(TipoPlaca nuevo) {
    if (nuevo == _tipoPlaca) return;
    var correlativo = _placaController.text.trim().toUpperCase();
    if (correlativo.startsWith(_tipoPlaca.prefijo)) {
      correlativo = correlativo.substring(1);
    }
    setState(() {
      _tipoPlaca = nuevo;
      _placaController.text = componerPlaca(nuevo, correlativo);
    });
  }

  String _etiquetaTipoPlaca(TipoPlaca tipo) {
    switch (tipo) {
      case TipoPlaca.particular:
        return context.l10n.addVehiclePlateTypeParticular;
      case TipoPlaca.moto:
        return context.l10n.addVehiclePlateTypeMoto;
      case TipoPlaca.carga:
        return context.l10n.addVehiclePlateTypeCarga;
      case TipoPlaca.alquiler:
        return context.l10n.addVehiclePlateTypeAlquiler;
    }
  }

  Widget _buildTipoPlacaSelector() {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l10n.addVehiclePlateType,
            style: AppTextStyles.labelLarge.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tipo in TipoPlaca.values)
              ChoiceChip(
                label: Text(_etiquetaTipoPlaca(tipo)),
                selected: _tipoPlaca == tipo,
                onSelected: (_) => _cambiarTipoPlaca(tipo),
                showCheckmark: false,
                selectedColor: widget.primaryColor.withValues(alpha: 0.15),
                backgroundColor: colors.surfaceContainer,
                labelStyle: AppTextStyles.labelLarge.copyWith(
                  color: _tipoPlaca == tipo
                      ? widget.primaryColor
                      : colors.textSecondary,
                  fontWeight: _tipoPlaca == tipo
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide(
                  color: _tipoPlaca == tipo
                      ? widget.primaryColor
                      : colors.outline.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Trae a la vista el primer campo que bloqueó el envío. Se hace en el
  /// frame siguiente para que el texto de error ya esté maquetado.
  void _revelarCampo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    });
  }

  // Solo letras (con acentos/ñ) y espacios, 3-30 caracteres: "Gris13" pasó
  // a producción porque este campo era texto libre.
  static final RegExp _colorValidoRegExp = RegExp(
    r'^[A-Za-zÁÉÍÓÚáéíóúÑñ ]{3,30}$',
  );

  @override
  void initState() {
    super.initState();
    _fetchAllMakes();
  }

  Future<void> _fetchAllMakes() async {
    setState(() {
      _isLoadingMakes = true;
      _makesError = null;
    });
    try {
      final makes = await _apiService.fetchAllMakes();
      setState(() {
        _allMakes = makes;
        _isLoadingMakes = false;
      });
    } catch (e) {
      setState(() {
        _makesError = e.toString();
        _isLoadingMakes = false;
      });
    }
  }

  Future<void> _fetchModels(String makeName) async {
    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
    });
    try {
      final models = await _apiService.fetchModelsByMake(makeName);
      setState(() {
        _makeModels = models;
        _isLoadingModels = false;
      });
    } catch (e) {
      setState(() {
        _modelsError = e.toString();
        _isLoadingModels = false;
      });
    }
  }

  void _nextStep() {
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.transformDuration(
                context,
                AppMotion.sheetEnter,
              ),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBrandStep();
      case 1:
        return _buildModelStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildSuccessStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepHeader(String title, String subtitle) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStep > 0 && _currentStep < 3)
            IconButton(
              onPressed: _prevStep,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBrandStep() {
    final colors = context.appColors;
    final popularMakesLower = _popularMakes
        .map((e) => e.toLowerCase())
        .toList();

    List<CarMake> filteredMakes;

    if (_brandSearchQuery.trim().isEmpty) {
      filteredMakes = _allMakes
          .where((m) => popularMakesLower.contains(m.makeName.toLowerCase()))
          .toList();

      filteredMakes.sort((a, b) {
        return popularMakesLower
            .indexOf(a.makeName.toLowerCase())
            .compareTo(popularMakesLower.indexOf(b.makeName.toLowerCase()));
      });
    } else {
      filteredMakes = _allMakes
          .where(
            (m) => m.makeName.toLowerCase().contains(
              _brandSearchQuery.trim().toLowerCase(),
            ),
          )
          .take(50)
          .toList();

      filteredMakes.sort((a, b) {
        final aLower = a.makeName.toLowerCase();
        final bLower = b.makeName.toLowerCase();
        final aIsPopular = popularMakesLower.contains(aLower);
        final bIsPopular = popularMakesLower.contains(bLower);

        if (aIsPopular && !bIsPopular) return -1;
        if (!aIsPopular && bIsPopular) return 1;
        return aLower.compareTo(bLower);
      });
    }

    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          context.l10n.addVehicleBrand,
          context.l10n.addVehicleBrandSubtitle,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppTextField(
            hintText: context.l10n.addVehicleSearchBrand,
            prefixIcon: const Icon(Icons.search),
            onChanged: (val) {
              setState(() => _brandSearchQuery = val);
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingMakes
              ? const Center(child: CircularProgressIndicator())
              : _makesError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.addVehicleErrorBrands,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.error,
                        ),
                      ),
                      AppButton(
                        text: context.l10n.addVehicleRetry,
                        type: AppButtonType.text,
                        size: AppButtonSize.small,
                        onPressed: _fetchAllMakes,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filteredMakes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filteredMakes.length) {
                      return ListTile(
                        title: Text(
                          context.l10n.addVehicleNotFoundBrand,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: widget.primaryColor,
                          ),
                        ),
                        onTap: _showManualBrandInput,
                      );
                    }
                    final make = filteredMakes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          make.makeName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        onTap: () {
                          setState(() => _selectedBrand = make.makeName);
                          _fetchModels(make.makeName);
                          _nextStep();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModelStep() {
    final colors = context.appColors;
    final filteredModels = _makeModels
        .where(
          (m) => m.modelName.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .take(50)
        .toList();

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          context.l10n.addVehicleModel,
          context.l10n.addVehicleModelSubtitle(_selectedBrand ?? ''),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppTextField(
            hintText: context.l10n.addVehicleSearchModel,
            prefixIcon: const Icon(Icons.search),
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingModels
              ? const Center(child: CircularProgressIndicator())
              : _modelsError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.addVehicleErrorModels,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.error,
                        ),
                      ),
                      AppButton(
                        text: context.l10n.addVehicleRetry,
                        type: AppButtonType.text,
                        size: AppButtonSize.small,
                        onPressed: () => _fetchModels(_selectedBrand!),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filteredModels.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filteredModels.length) {
                      return ListTile(
                        title: Text(
                          context.l10n.addVehicleNotFoundModel,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: widget.primaryColor,
                          ),
                        ),
                        onTap: _showManualModelInput,
                      );
                    }
                    final model = filteredModels[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          model.modelName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        onTap: () {
                          setState(() => _selectedModel = model.modelName);
                          _nextStep();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    final colors = context.appColors;
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              context.l10n.addVehicleDetails,
              context.l10n.addVehicleDetailsSubtitle,
            ),
            _buildTipoPlacaSelector(),
            KeyedSubtree(
              key: _placaFieldKey,
              child: _buildTextField(
                context.l10n.addVehiclePlate,
                context.l10n.addVehiclePlateHint,
                _placaController,
                Icons.badge,
                formatters: [PlateFormatter(tipo: _tipoPlaca)],
                validator: validarPlacaElSalvador,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  key: _anioFieldKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _showYearPicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: widget.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.addVehicleYear,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _anioController.text.isEmpty
                                        ? context.l10n.addVehicleYearHint
                                        : _anioController.text,
                                    style: TextStyle(
                                      // Un placeholder NO puede parecer un
                                      // valor elegido: hasta 2026-08-28 aqui
                                      // se pintaba el literal '2024' en
                                      // bold/textPrimary, y el usuario no
                                      // tenia forma de saber que el campo
                                      // seguia vacio. Al enviar saltaba "Ano
                                      // invalido" senalando un campo que a
                                      // la vista tenia un ano correcto.
                                      fontWeight: _anioController.text.isEmpty
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      color: _anioController.text.isEmpty
                                          ? colors.textSecondary
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_anioError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _anioError!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  key: _colorFieldKey,
                  child: _buildTextField(
                    context.l10n.addVehicleColor,
                    context.l10n.addVehicleColorHint,
                    _colorController,
                    Icons.palette,
                    // Mismo mecanismo que el resto del formulario: un solo
                    // sitio (`_colorError`) decide el mensaje, sin una ruta
                    // paralela de snackbar. T19 reutilizara este campo para
                    // el validador de formato.
                    errorText: _colorError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _kilometrajeFieldKey,
              child: _buildTextField(
                context.l10n.addVehicleMileage,
                '0',
                _kilometrajeController,
                Icons.speed,
                keyboardType: TextInputType.number,
                errorText: _kilometrajeError,
                isRequired: true,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.addVehicleDocs,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildDatePicker(
              context.l10n.addVehicleCardExp,
              _vencimientoTarjeta,
              (d) => setState(() => _vencimientoTarjeta = d),
            ),
            const SizedBox(height: 12),
            _buildDatePicker(
              context.l10n.addVehicleSoatExp,
              _vencimientoSoat,
              (d) => setState(() => _vencimientoSoat = d),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: context.l10n.addVehicleFinish,
                size: AppButtonSize.large,
                onPressed: () {
                  // La placa es el primer campo del paso y el botón el
                  // último: sin traerla a la vista, su error queda fuera de
                  // pantalla y el envío parece fallar sin motivo.
                  if (!(_formKey.currentState?.validate() ?? false)) {
                    _revelarCampo(_placaFieldKey);
                    return;
                  }

                  final anio = int.tryParse(_anioController.text);
                  final currentYear = DateTime.now().year;
                  if (anio == null || anio < 1900 || anio > currentYear) {
                    setState(
                      () => _anioError = context.l10n.addVehicleYearInvalid,
                    );
                    _revelarCampo(_anioFieldKey);
                    return;
                  }
                  setState(() => _anioError = null);

                  if (_colorController.text.trim().isEmpty) {
                    setState(
                      () => _colorError = context.l10n.addVehicleColorRequired,
                    );
                    _revelarCampo(_colorFieldKey);
                    return;
                  }
                  // "Gris13" llegó a producción porque el campo era texto
                  // libre sin más validación que "no vacío". El patrón ya
                  // acota 3-30 caracteres, así que reemplaza (no se suma a)
                  // el chequeo de longitud que había aquí antes.
                  if (!_colorValidoRegExp.hasMatch(_colorController.text)) {
                    setState(
                      () => _colorError =
                          context.l10n.addVehicleColorInvalidChars,
                    );
                    _revelarCampo(_colorFieldKey);
                    return;
                  }
                  setState(() => _colorError = null);

                  // Mismo mecanismo que año y color: el error va al propio
                  // campo. El snackbar que había aquí quedaba detrás del
                  // modal sheet a pantalla completa, y como el kilometraje
                  // se deja vacío con facilidad (su hint es '0'), este era
                  // el camino por el que "Finalizar Registro" no hacía nada.
                  final kmTexto = _kilometrajeController.text.trim();
                  if (kmTexto.isEmpty) {
                    setState(
                      () => _kilometrajeError =
                          context.l10n.addVehicleMileageRequired,
                    );
                    _revelarCampo(_kilometrajeFieldKey);
                    return;
                  }
                  final km = int.tryParse(kmTexto);
                  if (km == null || km < 0) {
                    setState(
                      () => _kilometrajeError =
                          context.l10n.addVehicleMileageInvalid,
                    );
                    _revelarCampo(_kilometrajeFieldKey);
                    return;
                  }
                  setState(() => _kilometrajeError = null);

                  _nextStep();
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStep() {
    final colors = context.appColors;
    return Padding(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 80, color: colors.success),
          const SizedBox(height: 24),
          Text(
            context.l10n.addVehicleSuccess,
            style: AppTextStyles.headlineSmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.addVehicleSuccessDesc(
              _selectedBrand ?? '',
              _selectedModel ?? '',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getColorFromName(
                _colorController.text,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.directions_car_filled_rounded,
                  size: 100,
                  color: _getColorFromName(_colorController.text),
                ),
                const SizedBox(height: 16),
                Text(
                  '$_selectedBrand $_selectedModel',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: context.l10n.addVehicleGoDashboard,
              size: AppButtonSize.large,
              isLoading: _isFinishing,
              onPressed: _isFinishing
                  ? null
                  : () async {
                      setState(() => _isFinishing = true);

                      final vehicle = VehicleModel(
                        idVehiculo: '', // Will be set by provider
                        idPropietario: '', // Will be set by provider
                        placa: _placaController.text,
                        marca: _selectedBrand ?? '',
                        modelo: _selectedModel ?? '',
                        anio: int.tryParse(_anioController.text) ?? 0,
                        color: _colorController.text,
                        kilometrajeActual:
                            int.tryParse(_kilometrajeController.text) ?? 0,
                        vencimientoTarjeta: _vencimientoTarjeta,
                        vencimientoSoat: _vencimientoSoat,
                      );

                      try {
                        await widget.onFinish(vehicle);
                      } catch (e) {
                        // Si falla, permitimos reintentar
                        if (mounted) {
                          setState(() => _isFinishing = false);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    String? errorText,
    bool isRequired = false,
  }) {
    return AppTextField(
      label: label,
      hintText: hint,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      errorText: errorText,
      isRequired: isRequired,
      prefixIcon: Icon(icon, color: widget.primaryColor, size: 20),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? value,
    Function(DateTime) onChanged,
  ) {
    final colors = context.appColors;
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (date != null) onChanged(date);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: widget.primaryColor, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                Text(
                  value != null
                      ? DateFormat('dd/MM/yyyy').format(value)
                      : context.l10n.addVehicleSelectDate,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualBrandInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresa la marca'),
        content: AppDialogContent(
          child: AppTextField(
            controller: controller,
            hintText: 'Ej: Tesla',
            textInputAction: TextInputAction.done,
          ),
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            text: 'Continuar',
            size: AppButtonSize.small,
            onPressed: () {
              setState(() {
                _selectedBrand = controller.text;
                _selectedModel = null;
              });
              Navigator.pop(context);
              _fetchModels(controller.text);
              _nextStep();
            },
          ),
        ],
      ),
    );
  }

  void _showManualModelInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresa el modelo'),
        content: AppDialogContent(
          child: AppTextField(
            controller: controller,
            hintText: 'Ej: Model 3',
            textInputAction: TextInputAction.done,
          ),
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            text: 'Continuar',
            size: AppButtonSize.small,
            onPressed: () {
              setState(() => _selectedModel = controller.text);
              Navigator.pop(context);
              _nextStep();
            },
          ),
        ],
      ),
    );
  }

  void _showYearPicker() {
    final years = List.generate(
      50,
      (index) => (DateTime.now().year - index).toString(),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surface,
      builder: (context) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Selecciona el Año',
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 18,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) => ListTile(
                  title: Center(
                    child: Text(
                      years[index],
                      style: TextStyle(
                        fontSize: 20,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                  ),
                  onTap: () {
                    setState(() => _anioController.text = years[index]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rojo':
        return Colors.red;
      case 'azul':
        return Colors.blue;
      case 'verde':
        return Colors.green;
      case 'amarillo':
        return Colors.yellow;
      case 'negro':
        return Colors.black;
      case 'blanco':
        return Colors.grey[400]!;
      case 'gris':
        return Colors.grey;
      case 'plateado':
        return Colors.blueGrey[200]!;
      default:
        return widget.primaryColor;
    }
  }
}
