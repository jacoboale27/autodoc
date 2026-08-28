import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/admin/data/services/admin_service.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/core/models/admin_log_model.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

class FakeAdminRepository implements AdminRepository {
  String? lastUpdatedUid;
  String? lastUpdatedEstado;
  String? lastUpdatedTallerId;
  String? lastUpdatedTallerEstado;
  AdminLogModel? lastLog;

  @override
  Future<void> updateUsuarioEstado(String uid, String nuevoEstado) async {
    lastUpdatedUid = uid;
    lastUpdatedEstado = nuevoEstado;
  }

  @override
  Future<void> updateTallerEstado(String idTaller, String nuevoEstado) async {
    lastUpdatedTallerId = idTaller;
    lastUpdatedTallerEstado = nuevoEstado;
  }

  @override
  Future<void> suspenderCuenta({
    required String coleccion,
    required String docId,
    required String motivo,
  }) async {
    if (coleccion == FirestoreCollections.usuarios) {
      lastUpdatedUid = docId;
      lastUpdatedEstado = 'suspendido';
    } else {
      lastUpdatedTallerId = docId;
      lastUpdatedTallerEstado = 'suspendido';
    }
  }

  @override
  Future<void> reactivarCuenta({
    required String coleccion,
    required String docId,
    String estadoActivo = 'activo',
  }) async {
    if (coleccion == FirestoreCollections.usuarios) {
      lastUpdatedUid = docId;
      lastUpdatedEstado = estadoActivo;
    } else {
      lastUpdatedTallerId = docId;
      lastUpdatedTallerEstado = estadoActivo;
    }
  }

  @override
  Future<void> registrarLog(AdminLogModel log) async {
    lastLog = log;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAdminRepository fakeRepository;
  late AdminService adminService;

  setUp(() {
    fakeRepository = FakeAdminRepository();
    adminService = AdminService(repository: fakeRepository);
  });

  group('AdminService Tests', () {
    test('aprobarUsuario updates state to activo and logs action', () async {
      await adminService.aprobarUsuario('admin1', 'user1');

      expect(fakeRepository.lastUpdatedUid, 'user1');
      expect(
        fakeRepository.lastUpdatedEstado,
        'activo',
        reason:
            "usa 'activo', no 'aprobado', para converger en un unico "
            'valor real de aprobacion (ver task-fased-fixwave-brief.md).',
      );
      expect(fakeRepository.lastLog?.adminUid, 'admin1');
      expect(fakeRepository.lastLog?.accion, 'APROBAR_USUARIO');
    });

    test('suspenderUsuario updates state and logs action', () async {
      await adminService.suspenderUsuario(
        'admin1',
        'user1',
        'Incumplimiento de normas',
      );

      expect(fakeRepository.lastUpdatedUid, 'user1');
      expect(fakeRepository.lastUpdatedEstado, 'suspendido');
      expect(fakeRepository.lastLog?.adminUid, 'admin1');
      expect(fakeRepository.lastLog?.accion, 'SUSPENDER_USUARIO');
      expect(fakeRepository.lastLog?.detalle, 'Incumplimiento de normas');
    });

    test('aprobarTaller updates usuarios/{uid} (NOT talleres, which is a '
        'read-only projection kept in sync by publishTallerProfile) and logs '
        'action', () async {
      await adminService.aprobarTaller('admin1', 'taller1');

      expect(
        fakeRepository.lastUpdatedUid,
        'taller1',
        reason:
            'talleres/{uid} es una proyeccion de solo lectura de '
            'usuarios/{uid}; escribir en talleres se revierte '
            'silenciosamente en el proximo write a usuarios.',
      );
      expect(fakeRepository.lastUpdatedEstado, 'aprobado');
      expect(fakeRepository.lastUpdatedTallerId, isNull);
      expect(fakeRepository.lastLog?.adminUid, 'admin1');
      expect(fakeRepository.lastLog?.accion, 'APROBAR_TALLER');
      expect(fakeRepository.lastLog?.detalle, 'Taller verificado y aprobado');
    });

    test(
      'rechazarTaller updates usuarios/{uid} (not talleres) and logs action',
      () async {
        await adminService.rechazarTaller(
          'admin1',
          'taller1',
          motivo: 'La foto de la fachada no deja ver el rótulo',
        );

        expect(fakeRepository.lastUpdatedUid, 'taller1');
        expect(fakeRepository.lastUpdatedEstado, 'rechazado');
        expect(fakeRepository.lastUpdatedTallerId, isNull);
        expect(fakeRepository.lastLog?.accion, 'RECHAZAR_TALLER');
      },
    );

    test('rechazarTaller guarda el motivo como detalle del log', () async {
      // Antes escribia siempre el literal 'Taller rechazado': el taller no
      // tenia forma de saber que corregir y reenviaba lo mismo.
      await adminService.rechazarTaller(
        'admin1',
        'taller1',
        motivo: '  La dirección no coincide con la fachada  ',
      );

      expect(
        fakeRepository.lastLog?.detalle,
        'La dirección no coincide con la fachada',
      );
    });

    test('rechazarTaller se niega a rechazar sin motivo', () async {
      for (final motivo in ['', '   ']) {
        expect(
          () =>
              adminService.rechazarTaller('admin1', 'taller1', motivo: motivo),
          throwsArgumentError,
        );
      }

      // Y no deja el rechazo aplicado a medias.
      expect(fakeRepository.lastUpdatedEstado, isNull);
    });

    test('suspenderTaller writes estado=suspendido to usuarios/{uid}, not '
        'talleres/{uid} (regression test: talleres is a read-only projection '
        'synced by the publishTallerProfile Cloud Function from usuarios; '
        'writing to talleres directly gets silently reverted and does not '
        'restrict app access, since firestore.rules gates isMecanico() on '
        'usuarios/{uid}.estado)', () async {
      await adminService.suspenderTaller('admin1', 'taller1', 'Falta de pagos');

      expect(fakeRepository.lastUpdatedUid, 'taller1');
      expect(fakeRepository.lastUpdatedEstado, 'suspendido');
      expect(
        fakeRepository.lastUpdatedTallerId,
        isNull,
        reason: 'suspenderTaller no debe escribir en talleres/{uid}',
      );
      expect(fakeRepository.lastLog?.adminUid, 'admin1');
      expect(fakeRepository.lastLog?.accion, 'SUSPENDER_TALLER');
      expect(fakeRepository.lastLog?.detalle, 'Falta de pagos');
    });

    test('reactivarTaller writes estado=aprobado to usuarios/{uid}, not '
        'talleres/{uid}', () async {
      await adminService.reactivarTaller('admin1', 'taller1');

      expect(fakeRepository.lastUpdatedUid, 'taller1');
      expect(fakeRepository.lastUpdatedEstado, 'aprobado');
      expect(fakeRepository.lastUpdatedTallerId, isNull);
      expect(fakeRepository.lastLog?.accion, 'REACTIVAR_TALLER');
    });
  });
}
