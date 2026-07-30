# Firebase Startup Resilience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep AutoDoc usable when Firebase initialization fails, while updating the Android file picker dependency and preserving Firebase configuration in environment variables.

**Architecture:** The app entry point will obtain a typed result from a small bootstrap helper. A successful result permits all Firebase-dependent initialization; a failed result renders a dedicated, non-Firebase error screen and stops startup. The web API key remains exclusively in `.env`.

**Tech Stack:** Flutter, Firebase Core, flutter_dotenv, flutter_test, Pub/Gradle.

## Global Constraints

- Keep Firebase credentials out of Dart source; use `.env` only.
- Do not initialize Firestore, Messaging, notification services, or providers that use Firebase after Firebase Core fails.
- Upgrade `file_picker` from `^3.0.4` to `^12.0.0-beta.7`, which is compatible with the project's `win32 6.x` dependency.
- Preserve unrelated working-tree changes.

---

### Task 1: Testable Firebase bootstrap result

**Files:**
- Create: `lib/core/bootstrap/firebase_bootstrap.dart`
- Create: `test/core/bootstrap/firebase_bootstrap_test.dart`

**Interfaces:**
- Produces: `Future<FirebaseBootstrapResult> FirebaseBootstrap.initialize(Future<void> Function() initializer)`.
- Produces: `bool FirebaseBootstrapResult.isReady` and `Object? FirebaseBootstrapResult.error`.

- [ ] **Step 1: Write the failing tests**

```dart
test('reports ready when Firebase initialization succeeds', () async {
  final result = await FirebaseBootstrap.initialize(() async {});
  expect(result.isReady, isTrue);
  expect(result.error, isNull);
});

test('reports an error instead of rethrowing when Firebase initialization fails', () async {
  final result = await FirebaseBootstrap.initialize(() async {
    throw StateError('invalid API key');
  });
  expect(result.isReady, isFalse);
  expect(result.error, isA<StateError>());
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/core/bootstrap/firebase_bootstrap_test.dart`

- [ ] **Step 3: Implement the minimal bootstrap helper**

```dart
class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._({required this.isReady, this.error});
  final bool isReady;
  final Object? error;
}

class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize(
    Future<void> Function() initializer,
  ) async {
    try {
      await initializer();
      return const FirebaseBootstrapResult._(isReady: true);
    } catch (error) {
      return FirebaseBootstrapResult._(isReady: false, error: error);
    }
  }
}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `flutter test test/core/bootstrap/firebase_bootstrap_test.dart`

### Task 2: Useful failure screen and guarded startup

**Files:**
- Create: `lib/core/widgets/firebase_initialization_error_screen.dart`
- Create: `test/core/widgets/firebase_initialization_error_screen_test.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `FirebaseInitializationErrorScreen` widget with no Firebase dependency.
- Consumes: `FirebaseBootstrapResult` in `main`.

- [ ] **Step 1: Write the failing widget test**

```dart
await tester.pumpWidget(const MaterialApp(
  home: FirebaseInitializationErrorScreen(),
));
expect(find.text('No pudimos iniciar AutoDoc'), findsOneWidget);
expect(find.textContaining('Firebase'), findsOneWidget);
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/core/widgets/firebase_initialization_error_screen_test.dart`

- [ ] **Step 3: Implement the error screen and guard initialization**

```dart
final firebaseResult = await FirebaseBootstrap.initialize(
  () => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
);
if (!firebaseResult.isReady) {
  runApp(const FirebaseInitializationErrorApp());
  return;
}
```

- [ ] **Step 4: Run focused tests and static analysis**

Run: `flutter test test/core/bootstrap/firebase_bootstrap_test.dart test/core/widgets/firebase_initialization_error_screen_test.dart && flutter analyze lib/main.dart lib/core/bootstrap/firebase_bootstrap.dart lib/core/widgets/firebase_initialization_error_screen.dart`

### Task 3: Environment key and Android dependency

**Files:**
- Modify: `.env`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

- [ ] **Step 1: Replace only `FIREBASE_WEB_API_KEY` in `.env`**

```text
FIREBASE_WEB_API_KEY=YOUR_API_KEY_HERE
```

- [ ] **Step 2: Upgrade `file_picker` and resolve packages**

```yaml
file_picker: ^12.0.0-beta.7
```

Run: `flutter pub get`

- [ ] **Step 3: Verify Android compilation and full Flutter tests**

Run: `flutter build apk --debug && flutter test`
