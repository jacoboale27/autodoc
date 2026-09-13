import 'package:autodoc/core/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/test_helpers.mocks.dart';
import 'app_router_test.dart'
    show FakeAuthSessionProvider, FakeUserProfileProvider;

class EmailSession extends FakeAuthSessionProvider {
  EmailSession(this.firebaseUser) : super(isLoggedIn: true, currentUid: 'uid');
  final User firebaseUser;
  @override
  User get user => firebaseUser;
}

void main() {
  test(
    'gate remains stable without profile and rejects anonymous sessions',
    () {
      for (final loggedIn in [false, true]) {
        expect(
          resolveRedirect(
            isLoggedIn: loggedIn,
            emailVerified: false,
            userData: null,
            isLoading: true,
            hasAttemptedFetch: false,
            profileError: 'offline',
            currentPath: '/verify_email',
          ),
          loggedIn ? null : '/login',
        );
      }
    },
  );

  test('public entry routes remain available before login', () {
    for (final path in ['/', '/login', '/register', '/onboarding']) {
      expect(
        resolveRedirect(
          isLoggedIn: false,
          emailVerified: false,
          userData: null,
          isLoading: false,
          hasAttemptedFetch: false,
          profileError: null,
          currentPath: path,
        ),
        isNull,
        reason: path,
      );
    }
  });

  testWidgets('unverified session blocks every route before profile loading', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    final user = MockUser();
    when(user.emailVerified).thenReturn(false);
    final session = EmailSession(user);
    final router = createAppRouter(session, FakeUserProfileProvider());
    addTearDown(router.dispose);
    for (final path in [
      '/dashboard',
      '/profile_setup',
      '/chat/123',
      '/admin/seed',
      '/login',
      '/register',
      '/',
      '/onboarding',
    ]) {
      final uri = Uri.parse(path);
      final state = GoRouterState(
        router.configuration,
        uri: uri,
        matchedLocation: path,
        fullPath: path,
        pathParameters: {},
        pageKey: const ValueKey('test'),
      );
      expect(
        appRouterRedirect(
          session,
          FakeUserProfileProvider(isLoading: true),
          context,
          state,
        ),
        '/verify_email',
        reason: path,
      );
    }
  });
}
