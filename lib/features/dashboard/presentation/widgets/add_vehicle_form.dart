import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/utils/plate_formatter.dart';
import '../../../../core/models/nhtsa_models.dart';
import '../../../../core/services/vehicle_api_service.dart';
import '../../../../core/theme/app_colors.dart';

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
  int _currentStep = 0;
  bool _isFinishing = false; // Nueva variable para controlar el estado final
  
  // Selection data
  String? _selectedBrand;
  String? _selectedModel;
  String _searchQuery = '';
  String _brandSearchQuery = '';
  
  static const List<String> _popularMakes = [
    'Toyota', 'Nissan', 'Honda', 'Hyundai', 'Kia', 'Chevrolet', 'Ford', 'Mazda', 
    'Volkswagen', 'Renault', 'Peugeot', 'Suzuki', 'Mitsubishi', 'Subaru', 'BMW', 
    'Mercedes-Benz', 'Audi', 'Jeep', 'Fiat', 'Dodge', 'Volvo', 'Lexus', 'Porsche', 
    'Land Rover', 'Jaguar', 'Mini', 'Alfa Romeo', 'Acura', 'Infiniti', 'Lincoln', 
    'Buick', 'Cadillac', 'Chrysler', 'GMC', 'Ram', 'Tesla', 'Seat', 'Skoda', 
    'Citroen', 'Chery', 'MG', 'JAC', 'Changan', 'Geely', 'Great Wall', 'BYD', 
    'Haval', 'SsangYong', 'Isuzu', 'Aston Martin', 'Ferrari', 'Lamborghini',
    'Maserati', 'McLaren', 'Bentley', 'Rolls Royce', 'Genesis', 'Smart'
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
              duration: const Duration(milliseconds: 300),
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
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.textPrimary),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
    final popularMakesLower = _popularMakes.map((e) => e.toLowerCase()).toList();

    List<CarMake> filteredMakes;
    
    if (_brandSearchQuery.trim().isEmpty) {
      filteredMakes = _allMakes
          .where((m) => popularMakesLower.contains(m.makeName.toLowerCase()))
          .toList();
          
      filteredMakes.sort((a, b) {
        return popularMakesLower.indexOf(a.makeName.toLowerCase())
            .compareTo(popularMakesLower.indexOf(b.makeName.toLowerCase()));
      });
    } else {
      filteredMakes = _allMakes
          .where((m) => m.makeName.toLowerCase().contains(_brandSearchQuery.trim().toLowerCase()))
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
        _buildStepHeader('Marca', '¿Cuál es la marca de tu vehículo?'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar marca...',
              hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: colors.textSecondary),
              filled: true,
              fillColor: colors.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
                          const Text('Error al cargar marcas', style: TextStyle(color: Colors.red)),
                          TextButton(onPressed: _fetchAllMakes, child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: filteredMakes.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filteredMakes.length) {
                          return ListTile(
                            title: Text('No encuentro mi marca...', style: TextStyle(fontStyle: FontStyle.italic, color: widget.primaryColor)),
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
                            title: Text(make.makeName, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textSecondary),
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
        .where((m) => m.modelName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .take(50)
        .toList();

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Modelo', 'Selecciona el modelo de tu $_selectedBrand'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar modelo...',
              hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: colors.textSecondary),
              filled: true,
              fillColor: colors.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
                          const Text('Error al cargar modelos', style: TextStyle(color: Colors.red)),
                          TextButton(onPressed: () => _fetchModels(_selectedBrand!), child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: filteredModels.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filteredModels.length) {
                          return ListTile(
                            title: Text('No encuentro mi modelo...', style: TextStyle(fontStyle: FontStyle.italic, color: widget.primaryColor)),
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
                            title: Text(model.modelName, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textSecondary),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Detalles finales', 'Completa la información restante'),
          _buildTextField('Número de Placa', 'e.g. P123-456', _placaController, Icons.badge, formatters: [PlateFormatter()]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showYearPicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: widget.primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Año', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                            Text(
                              _anioController.text.isEmpty ? '2024' : _anioController.text,
                              style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Color', 'Gris', _colorController, Icons.palette)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Kilometraje Actual', '0', _kilometrajeController, Icons.speed, keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          Text('Documentación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary)),
          const SizedBox(height: 12),
          _buildDatePicker('Vencimiento Tarjeta', _vencimientoTarjeta, (d) => setState(() => _vencimientoTarjeta = d)),
          const SizedBox(height: 12),
          _buildDatePicker('Vencimiento SOAT', _vencimientoSoat, (d) => setState(() => _vencimientoSoat = d)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_placaController.text.isEmpty) return;
                _nextStep();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Finalizar Registro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
          const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            '¡Vehículo Registrado!',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Tu $_selectedBrand $_selectedModel ya está en el garaje.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getColorFromName(_colorController.text).withValues(alpha: 0.1),
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
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20, color: colors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
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
                      kilometrajeActual: int.tryParse(_kilometrajeController.text) ?? 0,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isFinishing 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Ir al Dashboard', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTextField(String label, String hint, TextEditingController controller, IconData icon, {TextInputType? keyboardType, List<dynamic>? formatters}) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: colors.textPrimary),
          inputFormatters: formatters?.cast<TextInputFormatter>(), 
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: widget.primaryColor, size: 20),
            filled: true,
            fillColor: colors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onChanged) {
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
                Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                Text(
                  value != null ? DateFormat('dd/MM/yyyy').format(value) : 'Seleccionar fecha',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
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
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ej: Tesla')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedBrand = controller.text;
                _selectedModel = null;
              });
              Navigator.pop(context);
              _fetchModels(controller.text);
              _nextStep();
            },
            child: const Text('Continuar'),
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
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ej: Model 3')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() => _selectedModel = controller.text);
              Navigator.pop(context);
              _nextStep();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showYearPicker() {
    final years = List.generate(50, (index) => (DateTime.now().year - index).toString());
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surface,
      builder: (context) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Selecciona el Año', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: context.appColors.textPrimary)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) => ListTile(
                  title: Center(child: Text(years[index], style: TextStyle(fontSize: 20, color: context.appColors.textPrimary))),
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
      case 'rojo': return Colors.red;
      case 'azul': return Colors.blue;
      case 'verde': return Colors.green;
      case 'amarillo': return Colors.yellow;
      case 'negro': return Colors.black;
      case 'blanco': return Colors.grey[400]!;
      case 'gris': return Colors.grey;
      case 'plateado': return Colors.blueGrey[200]!;
      default: return widget.primaryColor;
    }
  }
}

