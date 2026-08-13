import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/constants/firestore_collections.dart';

/// Service that handles admin authentication through Firebase Auth.
/// Admin credentials are stored in Firebase Auth as real users, and their
/// admin status is validated via the 'Usuarios' Firestore collection (rol == 'Administrador').
class AdminAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AdminAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  /// Attempts to sign in as an administrator.
  /// 1. If [input] is not an email, tries to resolve it as a username from Firestore.
  /// 2. Signs in via Firebase Auth.
  /// 3. Validates that the user document in Firestore has rol == 'Administrador'.
  /// Returns a [UserModel] if valid admin, null otherwise.
  Future<UserModel?> loginAsAdmin(String input, String password) async {
    try {
      String email = input.trim();

      // If input doesn't look like an email, resolve username to email
      if (!email.contains('@')) {
        final resolved = await _resolveUsernameToEmail(email);
        if (resolved == null) return null;
        email = resolved;
      }

      // Authenticate with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      // Validar rol de administrador en Firestore
      final userDoc = await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return null;
      }

      final data = userDoc.data()!;
      final rol = (data['rol'] as String? ?? '').trim().toLowerCase();

      if (rol != 'administrador' && rol != 'admin' && rol != 'superusuario') {
        // No es administrador: cerrar la sesion que acabamos de abrir.
        await _auth.signOut();
        return null;
      }

      return UserModel.fromMap(data, user.uid);
    } on FirebaseAuthException catch (_) {
      // Auth pudo haber tenido exito parcial (p. ej. credenciales validas
      // pero fallo posterior); nunca dejar una sesion viva en un retorno null.
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      return null;
    } catch (_) {
      // La autenticacion pudo haber tenido exito y la excepcion venir de la
      // consulta a Firestore (sin conexion, PERMISSION_DENIED, etc.). No
      // dejar la sesion de Firebase Auth viva si vamos a retornar null.
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      return null;
    }
  }

  /// Checks if a given UID belongs to an admin in Firestore.
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(uid)
          .get();
      if (!doc.exists) return false;
      final rol = (doc.data()?['rol'] as String? ?? '').trim().toLowerCase();
      return rol == 'administrador' || rol == 'admin' || rol == 'superusuario';
    } catch (_) {
      return false;
    }
  }

  /// Retrieves admin user data by UID from Firestore.
  Future<UserModel?> getAdminByUid(String uid) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(uid)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final rol = (data['rol'] as String? ?? '').trim().toLowerCase();
      if (rol != 'administrador' && rol != 'admin' && rol != 'superusuario') {
        return null;
      }

      return UserModel.fromMap(data, uid);
    } catch (_) {
      return null;
    }
  }

  /// Resolves a username to an email by querying Firestore 'Usuarios' collection.
  Future<String?> _resolveUsernameToEmail(String username) async {
    try {
      // Try matching by a 'usuario' field if it exists
      final queryByUsuario = await _firestore
          .collection(FirestoreCollections.usuarios)
          .where('usuario', isEqualTo: username)
          .limit(1)
          .get();

      if (queryByUsuario.docs.isNotEmpty) {
        return queryByUsuario.docs.first.data()['correo'] as String?;
      }

      // Also try case-insensitive email prefix matching
      // e.g., username "admin" matches "admin@autodocsv.com"
      final queryByCorreo = await _firestore
          .collection(FirestoreCollections.usuarios)
          .where('correo', isGreaterThanOrEqualTo: '$username@')
          .where('correo', isLessThanOrEqualTo: '$username@\uf8ff')
          .limit(1)
          .get();

      if (queryByCorreo.docs.isNotEmpty) {
        return queryByCorreo.docs.first.data()['correo'] as String?;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Seeds admin accounts into Firebase Auth and Firestore.
  /// Call this once during initial setup or from a setup script.
  /// Returns a list of results for each admin account processed.
  Future<List<Map<String, String>>> seedAdminAccounts(
    List<Map<String, String>> adminCredentials,
  ) async {
    final results = <Map<String, String>>[];

    for (final admin in adminCredentials) {
      final email = admin['correo']!;
      final password = admin['password']!;
      final nombre = admin['nombre']!;
      final rol = admin['rol']!;
      final usuario = admin['usuario'] ?? '';

      try {
        // Try to create the Firebase Auth account
        UserCredential credential;
        try {
          credential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Account already exists, sign in to get the UID
            credential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } else {
            results.add({'email': email, 'status': 'error', 'detail': e.code});
            continue;
          }
        }

        final uid = credential.user!.uid;

        // Update display name in Firebase Auth
        await credential.user!.updateDisplayName(nombre);

        // Create/update the Firestore user document
        await _firestore
            .collection(FirestoreCollections.usuarios)
            .doc(uid)
            .set({
              'id_usuario': uid,
              'nombre_completo': nombre,
              'correo': email,
              'rol': rol,
              'usuario': usuario,
              'estado': 'activo',
              'fecha_registro': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        results.add({'email': email, 'status': 'success', 'uid': uid});
      } catch (e) {
        results.add({
          'email': email,
          'status': 'error',
          'detail': e.toString(),
        });
      }
    }

    return results;
  }
}
