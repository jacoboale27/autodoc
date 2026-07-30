import 'package:flutter/material.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:autodoc/core/models/vehicle_model.dart';

class ShareVehicleSheet extends StatefulWidget {
  final VehicleModel vehicle;
  final Function(VehicleModel) onUpdated;
  const ShareVehicleSheet({
    super.key,
    required this.vehicle,
    required this.onUpdated,
  });

  @override
  State<ShareVehicleSheet> createState() => _ShareVehicleSheetState();
}

class _ShareVehicleSheetState extends State<ShareVehicleSheet> {
  final _emailController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  bool _isLoading = false;
  List<Map<String, String>> _sharedUsers = []; // {uid, email, name}

  @override
  void initState() {
    super.initState();
    _loadSharedUsers();
  }

  // I1 (Fase C, revision de correcciones): 'usuarios' quedo cerrada a solo
  // lectura del propio documento (Tarea 8), asi que ya no se puede leer
  // usuarios/{uid} de cada usuario compartido directamente. La resolucion
  // pasa por la Cloud Function callable `obtenerUsuariosCompartidos`, que
  // verifica server-side que el llamante es el propietario del vehiculo.
  Future<void> _loadSharedUsers() async {
    try {
      final result = await _functions
          .httpsCallable('obtenerUsuariosCompartidos')
          .call({'vehicleId': widget.vehicle.idVehiculo});
      final data = (result.data as List?) ?? [];
      final users = data
          .map(
            (u) => {
              'uid': (u as Map)['uid']?.toString() ?? '',
              'email': u['correo']?.toString() ?? '',
              'name': u['nombre']?.toString() ?? 'Sin nombre',
            },
          )
          .toList();
      if (mounted) setState(() => _sharedUsers = users);
    } catch (e) {
      // No bloquea la hoja de compartir si la resolucion falla; el usuario
      // simplemente vera la lista de compartidos vacia.
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF522C81);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Icon(Icons.people_outline, color: primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Compartir Vehículo',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.vehicle.marca ?? ''} ${widget.vehicle.modelo ?? ''} • ${widget.vehicle.placa}',
            style: GoogleFonts.inter(fontSize: 13, color: subTextColor),
          ),
          const SizedBox(height: 20),

          // Email input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Agregar correo electrónico...',
                    hintStyle: TextStyle(
                      color: subTextColor.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      color: primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primary.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primary.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.person_add, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Shared users list
          Text(
            'PERSONAS CON ACCESO',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 12),

          if (_sharedUsers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primary.withValues(alpha: 0.1),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 32,
                    color: subTextColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Solo tú tienes acceso',
                    style: GoogleFonts.inter(fontSize: 13, color: subTextColor),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_sharedUsers.length, (i) {
              final user = _sharedUsers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primary.withValues(alpha: 0.12),
                      child: Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] ?? '',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          Text(
                            user['email'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.red.withValues(alpha: 0.6),
                        size: 18,
                      ),
                      onPressed: () => _removeUser(user['uid']!),
                      tooltip: 'Revocar acceso',
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _addUser() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _showSnack('Ingresa un correo válido');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // I1 (Fase C, revision de correcciones): la busqueda por correo sobre
      // 'usuarios' ya no es posible desde el cliente (Tarea 8 cerro esa
      // coleccion a solo lectura del propio documento). Se resuelve via la
      // Cloud Function callable `buscarPropietarioPorCorreo`, que verifica
      // que el llamante es el propietario del vehiculo y solo devuelve
      // cuentas con rol Propietario.
      final result = await _functions
          .httpsCallable('buscarPropietarioPorCorreo')
          .call({'vehicleId': widget.vehicle.idVehiculo, 'correo': email});
      final data = result.data as Map?;

      if (data == null) {
        _showSnack('No se encontró un usuario con ese correo');
        setState(() => _isLoading = false);
        return;
      }

      final targetUid = data['uid'] as String;

      if (targetUid == widget.vehicle.idPropietario) {
        _showSnack('No puedes compartir contigo mismo');
        setState(() => _isLoading = false);
        return;
      }

      if (widget.vehicle.sharedWith.contains(targetUid)) {
        _showSnack('Este usuario ya tiene acceso');
        setState(() => _isLoading = false);
        return;
      }

      // Update Firestore
      await _firestore
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehicle.idVehiculo)
          .update({
            'shared_with': FieldValue.arrayUnion([targetUid]),
          });

      final newShared = [...widget.vehicle.sharedWith, targetUid];
      widget.onUpdated(widget.vehicle.copyWith(sharedWith: newShared));

      _emailController.clear();
      await _loadSharedUsers();
      _showSnack('Acceso concedido ✓');
    } catch (e) {
      _showSnack('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _removeUser(String uid) async {
    try {
      await _firestore
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehicle.idVehiculo)
          .update({
            'shared_with': FieldValue.arrayRemove([uid]),
          });

      final newShared = widget.vehicle.sharedWith
          .where((u) => u != uid)
          .toList();
      widget.onUpdated(widget.vehicle.copyWith(sharedWith: newShared));

      setState(() => _sharedUsers.removeWhere((u) => u['uid'] == uid));
      _showSnack('Acceso revocado');
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
