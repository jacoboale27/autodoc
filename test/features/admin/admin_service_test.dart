import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/admin/data/services/admin_service.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/core/models/admin_log_model.dart';

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
        reason: "usa 'activo', no 'aprobado', para converger en un unico "
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

    test('aprobarTaller updates state and logs action', () async {
      await adminService.aprobarTaller('admin1', 'taller1');

      expect(fakeRepository.lastUpdatedTallerId, 'taller1');
      expect(fakeRepository.lastUpdatedTallerEstado, 'aprobado');
      expect(fakeRepository.lastLog?.adminUid, 'admin1');
      expect(fakeRepository.lastLog?.accion, 'APROBAR_TALLER');
      expect(fakeRepository.lastLog?.detalle, 'Taller verificado y aprobado');
    });

    test('suspenderTaller updates state and logs action', () async {
      await adminService.suspenderTaller('admin1', 'taller1', 'Falta de pagos');

      expect(fakeRepository.lastUpdatedTallerId, 'taller1');
      expect(fakeRepository.lastUpdatedTallerEstado, 'suspendido');
      expect(fakeRepository.lastLog?.adminUid, 'admin1');
      expect(fakeRepository.lastLog?.accion, 'SUSPENDER_TALLER');
      expect(fakeRepository.lastLog?.detalle, 'Falta de pagos');
    });
  });
}
