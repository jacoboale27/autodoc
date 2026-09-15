import 'package:flutter/material.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import '../../../../core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';

/// Also available from the dashboard before the recipient owns any vehicle.
Future<void> showVehicleInvitationAcceptance(
  BuildContext context, {
  Future<void> Function(String code)? acceptInvitation,
}) async {
  final l10n = AppLocalizations.of(context)!;
  var enteredCode = '';
  final code = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.securityAcceptInvitation),
      content: TextField(
        onChanged: (value) => enteredCode = value,
        decoration: InputDecoration(labelText: l10n.securityInvitationCode),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, enteredCode.trim()),
          child: Text(l10n.securityAcceptInvitation),
        ),
      ],
    ),
  );
  if (code == null || !context.mounted) return;
  try {
    if (acceptInvitation != null) {
      await acceptInvitation(code);
    } else {
      await FirebaseFunctions.instance
          .httpsCallable('aceptarInvitacionVehiculo')
          .call({'codigoInvitacion': code});
    }
    if (context.mounted) AppSnackbar.show(context, l10n.securityAccessAccepted);
  } catch (_) {
    if (context.mounted) AppSnackbar.show(context, l10n.securityRequestError);
  }
}

class ShareVehicleSheet extends StatefulWidget {
  final VehicleModel vehicle;
  final Function(VehicleModel) onUpdated;
  final Future<List<Map<String, String>>> Function()? loadSharedUsers;
  final Future<void> Function(String uid)? revokeAccess;
  const ShareVehicleSheet({
    super.key,
    required this.vehicle,
    required this.onUpdated,
    this.loadSharedUsers,
    this.revokeAccess,
  });

  @override
  State<ShareVehicleSheet> createState() => _ShareVehicleSheetState();
}

class _ShareVehicleSheetState extends State<ShareVehicleSheet> {
  final _emailController = TextEditingController();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;
  bool _isLoading = false;
  final _codeController = TextEditingController();
  String? _invitationCode;
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  List<Map<String, String>> _sharedUsers = []; // {uid, email, name}

  /// uids cuya revocacion esta en vuelo. Por uid y no una sola bandera: revocar
  /// a un usuario no tiene por que bloquear la fila de otro.
  final Set<String> _revocando = <String>{};

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
      if (widget.loadSharedUsers != null) {
        final users = await widget.loadSharedUsers!();
        if (mounted) setState(() => _sharedUsers = users);
        return;
      }
      final result = await _functions
          .httpsCallable('obtenerUsuariosCompartidos')
          .call({'vehicleId': widget.vehicle.idVehiculo});
      final data = (result.data as List?) ?? [];
      final users = data
          .map(
            (u) => {
              'uid': (u as Map)['uid']?.toString() ?? '',
              'email': u['correo']?.toString() ?? '',
              'name': u['nombre']?.toString() ?? l10n.securityUnnamed,
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
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    final primary = colors.primary;
    final textColor = colors.textPrimary;
    final subTextColor = colors.textSecondary;
    final cardColor = isDark
        ? colors.surfaceVariant.withValues(alpha: 0.65)
        : colors.surfaceContainer;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
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
                color: colors.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.xs),
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
                l10n.securityShareVehicle,
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 20,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.vehicle.marca ?? ''} ${widget.vehicle.modelo ?? ''} • ${widget.vehicle.placa}',
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 13,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 20),

          // Email input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _emailController,
                  hintText: l10n.securityEmailHint,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addUser(),
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                text: '',
                semanticLabel: l10n.securityRequestAccess,
                icon: const Icon(Icons.person_add),
                size: AppButtonSize.small,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _addUser,
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_invitationCode != null) ...[
            Text(l10n.securityDeliverCode),
            SelectableText(_invitationCode!),
            const SizedBox(height: 12),
          ],
          AppTextField(
            controller: _codeController,
            label: l10n.securityInvitationCode,
          ),
          AppButton(
            text: l10n.securityAcceptInvitation,
            onPressed: _isLoading ? null : _acceptInvitation,
          ),
          const SizedBox(height: 20),
          // Shared users list
          Text(
            l10n.securityPeopleWithAccess,
            style: AppTextStyles.labelSmall.copyWith(
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
                    l10n.securityOnlyYou,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13,
                      color: subTextColor,
                    ),
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
                        style: AppTextStyles.labelLarge.copyWith(
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
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          Text(
                            user['email'] ?? '',
                            style: AppTextStyles.bodySmall.copyWith(
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
                        color: colors.error.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      onPressed: _revocando.contains(user['uid'])
                          ? null
                          : () => _removeUser(user['uid']!),
                      tooltip: l10n.securityRevoke,
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
      _showSnack(l10n.securityInvalidEmail);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _functions
          .httpsCallable('buscarPropietarioPorCorreo')
          .call({'vehicleId': widget.vehicle.idVehiculo, 'correo': email});
      if (!mounted) return;
      setState(
        () => _invitationCode =
            (result.data as Map)['codigoInvitacion'] as String,
      );
      _emailController.clear();
      _showSnack(l10n.securityRequestPending);
    } catch (_) {
      _showSnack(l10n.securityRequestError);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _acceptInvitation() async {
    setState(() => _isLoading = true);
    try {
      await _functions.httpsCallable('aceptarInvitacionVehiculo').call({
        'codigoInvitacion': _codeController.text.trim(),
      });
      if (!mounted) return;
      _codeController.clear();
      _showSnack(l10n.securityAccessAccepted);
    } catch (_) {
      if (mounted) _showSnack(l10n.securityRequestError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeUser(String uid) async {
    // Guard de reentrada: el `onPressed: null` de arriba solo surte efecto en el
    // frame siguiente, asi que dos taps en el mismo frame llegarian los dos.
    if (_revocando.contains(uid)) return;
    setState(() => _revocando.add(uid));
    try {
      if (widget.revokeAccess != null) {
        await widget.revokeAccess!(uid);
      } else {
        await _firestore
            .collection(FirestoreCollections.vehiculos)
            .doc(widget.vehicle.idVehiculo)
            .update({
              'shared_with': FieldValue.arrayRemove([uid]),
            });
      }

      final newShared = widget.vehicle.sharedWith
          .where((u) => u != uid)
          .toList();
      widget.onUpdated(widget.vehicle.copyWith(sharedWith: newShared));

      setState(() => _sharedUsers.removeWhere((u) => u['uid'] == uid));
      _showSnack(l10n.securityAccessRevoked);
    } catch (e) {
      _showSnack(l10n.securityRequestError);
    } finally {
      if (mounted) setState(() => _revocando.remove(uid));
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      AppSnackbar.show(context, msg);
    }
  }
}
