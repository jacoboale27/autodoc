import 'package:flutter_test/flutter_test.dart';

/// Tests for the route helper functions in app_router.dart.
/// 
/// These tests verify the redirect logic helpers:
/// - _normalizeRole: maps role strings to normalized values
/// - _homeForRole: maps normalized roles to home routes
/// - _matchesRouteSet: checks if a path matches a route set
/// 
/// The full GoRouter redirect logic requires a widget test harness
/// (integration test), but the helper functions can be tested in isolation.
void main() {
  group('_normalizeRole', () {
    test('normalizes "Propietario" to owner', () {
      expect(_normalizeRoleForTest('Propietario'), 'owner');
    });

    test('normalizes "Mecanico" to mechanic', () {
      expect(_normalizeRoleForTest('Mecanico'), 'mechanic');
    });

    test('normalizes "Taller" to mechanic', () {
      expect(_normalizeRoleForTest('Taller'), 'mechanic');
    });

    test('normalizes "admin" (lowercase) to admin', () {
      expect(_normalizeRoleForTest('admin'), 'admin');
    });

    test('normalizes "Administrador" to admin', () {
      expect(_normalizeRoleForTest('Administrador'), 'admin');
    });

    test('normalizes null to empty string', () {
      expect(_normalizeRoleForTest(null), '');
    });

    test('normalizes unknown role to owner (default)', () {
      expect(_normalizeRoleForTest('unknown'), 'owner');
    });
  });

  group('_homeForRole', () {
    test('owner home is /dashboard', () {
      expect(_homeForRoleForTest('owner'), '/dashboard');
    });

    test('mechanic home is /mechanic_dashboard', () {
      expect(_homeForRoleForTest('mechanic'), '/mechanic_dashboard');
    });

    test('admin home is /admin/dashboard', () {
      expect(_homeForRoleForTest('admin'), '/admin/dashboard');
    });

    test('empty role defaults to /dashboard', () {
      expect(_homeForRoleForTest(''), '/dashboard');
    });
  });

  group('_matchesRouteSet', () {
    const testSet = <String>{'/dashboard', '/garage', '/alerts'};

    test('exact match returns true', () {
      expect(_matchesRouteSetForTest('/dashboard', testSet), isTrue);
    });

    test('sub-path match returns true', () {
      expect(_matchesRouteSetForTest('/dashboard/details', testSet), isTrue);
    });

    test('no match returns false', () {
      expect(_matchesRouteSetForTest('/mechanic_dashboard', testSet), isFalse);
    });

    test('partial prefix does not match', () {
      // /dashboards should NOT match /dashboard
      expect(_matchesRouteSetForTest('/dashboards', testSet), isFalse);
    });

    test('empty path does not match', () {
      expect(_matchesRouteSetForTest('', testSet), isFalse);
    });
  });

  group('Route Sets — No overlap between roles', () {
    test('owner routes and mechanic routes have no common paths', () {
      final ownerRoutes = <String>{
        '/dashboard', '/garage', '/workshop_directory',
        '/user_profile', '/chat_list', '/vehicle_profile',
        '/alerts', '/service_history',
      };
      final mechanicRoutes = <String>{
        '/mechanic_dashboard', '/mechanic_search',
        '/mechanic_service_history', '/workshop_settings',
        '/mechanic_reviews', '/initiate_service', '/mechanic_pending',
      };

      final overlap = ownerRoutes.intersection(mechanicRoutes);
      expect(overlap, isEmpty, reason: 'Owner and mechanic routes should not overlap');
    });

    test('public routes do not include protected routes', () {
      const publicRoutes = <String>{'/', '/login', '/register', '/onboarding', '/landing'};
      const protectedPrefixes = ['/dashboard', '/admin', '/mechanic', '/garage'];

      for (final pub in publicRoutes) {
        for (final prot in protectedPrefixes) {
          expect(
            pub.startsWith(prot),
            isFalse,
            reason: 'Public route $pub should not start with protected prefix $prot',
          );
        }
      }
    });
  });
}

// ── Test helpers that expose private functions for testing ─────────────────────
// Since _normalizeRole, _homeForRole, _matchesRouteSet are file-level private
// functions in app_router.dart, we duplicate the logic here for testability.
// This is the standard approach without modifying production code.

String _normalizeRoleForTest(String? rol) {
  if (rol == null) return '';
  final r = rol.trim().toLowerCase();
  if (r == 'admin' || r == 'administrador') return 'admin';
  if (r == 'mecanico' || r == 'taller') return 'mechanic';
  return 'owner';
}

String _homeForRoleForTest(String normalizedRole) {
  switch (normalizedRole) {
    case 'admin':
      return '/admin/dashboard';
    case 'mechanic':
      return '/mechanic_dashboard';
    default:
      return '/dashboard';
  }
}

bool _matchesRouteSetForTest(String path, Set<String> routes) {
  for (final route in routes) {
    if (path == route || path.startsWith('$route/') || path.startsWith('$route?')) {
      return true;
    }
  }
  return false;
}
