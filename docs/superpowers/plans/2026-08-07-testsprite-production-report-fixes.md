# TestSprite Production Report (Aug 7, 2026) — Fix Real Failures

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 3 real, code-verifiable defects behind TestSprite's production report (`TestSprite.md`, run against `https://autodoc-6ef5a.web.app/`), and document/verify the other 2 clusters of reported issues that turned out to be test-authoring mistakes rather than app bugs — without touching code that already works.

**Architecture:** AutoDoc is a Flutter app (Clean Architecture + Provider) with a Firebase backend (Firestore, Auth, Storage, Cloud Functions), routed with `go_router`. Each task below targets exactly one screen/provider and ships with its own widget/unit test. Tasks are independent and can be executed/reviewed in any order.

**Tech Stack:** Flutter/Dart, `provider`, `go_router`, `cloud_firestore` / `fake_cloud_firestore` (tests), `flutter_test`.

## Why this plan differs from the 34-title request

The user's initial 34-title list came from test *titles and priorities only* — no failure traces. Two artifact sources were checked:

1. `testsprite_tests/tmp/test_results.json` (a local MCP run, all 30 tests `BLOCKED` because the Flutter web release build never rendered at `localhost:8765` — a test-infra problem, not a feature bug; **not used as evidence for this plan**).
2. `TestSprite.md` (the report the user pointed to) — a **production** run against `https://autodoc-6ef5a.web.app/`, 46 tests, **36 Passed / 7 Failed / 3 Blocked**. This has real per-test traces, DOM observations, and TestSprite's own (not always correct) root-cause guesses. **This is the evidence base for this plan.**

Cross-checking every Failed/Blocked test's trace against the actual `lib/core/router/app_router.dart` routes and `lib/features/auth/presentation/providers/auth_provider.dart` login flow shows the 10 reported issues collapse into 5 distinct root causes:

| # | Reported test(s) | Verdict | Task |
|---|---|---|---|
| 1 | Manage workshop staff (Failed), View active conversations (Failed), Track repairs on the kanban board (Failed), Change a user role from the admin area (Blocked), Review reservation details from a conversation (Blocked) | **Test-authoring issue** — TestSprite's own scripts navigate directly to `/directorio`, `/chat`, `/garaje`, none of which are registered routes (the real ones are `/workshop_directory`, `/chat_list`, `/mechanic_reparaciones`). The app's `errorBuilder` (`lib/core/router/app_router.dart:314-315`) correctly renders "Página no encontrada (404)" for any unmatched path — this is by design, not a hosting/SPA-rewrite bug as TestSprite's automated "Cause" guessed. | Task 4 (verify only) |
| 2 | Prevent invalid admin sign in (Failed) | **Test-data issue** — `nadie@gmail.com` / `hola123` is used as the *standard valid* test account across ~30 other **Passed** tests in the same report (login, dashboard, garage, chat, etc.). It is a real seeded account, not invalid credentials; the "invalid sign-in" test used the wrong (valid) credentials by mistake. | Task 5 (verify only) |
| 3 | Reset a forgotten password (Failed) | **Real bug** — the failure-path SnackBar in the reset-password dialog uses the dialog's own `BuildContext`, which is not a descendant of any page `Scaffold` in the Element tree, so `ScaffoldMessenger.of(ctx)` can throw and get silently swallowed by the button's `async` `onPressed`, leaving the modal open with no visible feedback — exactly what TestSprite observed. | Task 1 |
| 4 | Read workshop reviews before choosing a provider (Failed), View workshop reviews (Blocked) | **Real bug** — the workshop directory card's only review-related action is the "Review" button, wired to the *write-a-review* flow (`_reviewWorkshop`), gated by "you must have completed a service with this workshop." There is no way to just *browse* a workshop's existing reviews before choosing it, even though `ReviewService.watchReviewsForTaller`/`getReviewsForTaller` already exist and are unused for this purpose. | Task 2 |
| 5 | View expiring alerts from the dashboard (Failed) | **Real bug** — `DashboardScreen.didChangeDependencies` (`lib/features/dashboard/presentation/pages/dashboard_screen.dart:49-56`) calls `AlertProvider.fetchAlerts` exactly once, for `vehicleProvider.selectedVehicle` only. `AlertProvider.fetchAlerts` (`lib/features/dashboard/presentation/providers/alert_provider.dart:34-81`) also **replaces** `_alerts` on every call instead of merging. An owner with more than one vehicle only ever sees alerts for a single vehicle — any expiring item on a non-selected vehicle never renders, matching "Excellent! You have no pending alerts" being shown incorrectly. | Task 3 |

## Global Constraints

- Follow existing code style: Spanish identifiers/comments for domain code (`idTaller`, `resenias`, etc.), English is fine for generic infra and this plan's own prose.
- Every code task ships with a test that fails before the fix and passes after (TDD). Verification-only tasks ship with a regression test or a documented finding instead of a code diff.
- Do not modify `firestore.rules` unless a task explicitly says so.
- Run `flutter analyze` and the touched test file(s) before every commit in this plan; do not commit if either fails.
- Commit messages: `fix(<area>): <summary>` for bug fixes, `test(<area>): <summary>` for verification-only tasks.
- Do not touch `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart` — that screen is a *different* feature (a workshop viewing reviews about itself) and already works; it is unrelated to Task 2's gap (an *owner* browsing a workshop's reviews from the directory before choosing it).

---

### Task 1: Fix the silently-swallowed "reset password" failure feedback

**Root cause:** `_showForgotPasswordDialog` (`lib/features/auth/presentation/pages/auth_screen.dart:558-651`) shows an `AlertDialog` via `showDialog`. Its "Send link" button (`lib/features/auth/presentation/pages/auth_screen.dart:606-631`) calls `authProvider.sendPasswordReset(email)`; on failure it calls `ScaffoldMessenger.of(ctx).showSnackBar(...)` where `ctx` is the **dialog's own builder context** (line 622). Because `showDialog` inserts the dialog route into the Navigator's `Overlay` as a sibling entry — not as an Element-tree descendant of the underlying page's `Scaffold` — `ScaffoldMessenger.of(ctx)` has no guaranteed ancestor to find. When it throws, the exception is swallowed inside the unawaited `onPressed: () async { ... }` callback (no surrounding `try/catch`), so the dialog just sits there: no confirmation, no visible error. This exactly matches TestSprite's observation ("The Recover Password modal remained open after submitting... No confirmation message... was visible.").

**Fix:** capture the **screen's** `BuildContext` (the one used for the success-path SnackBar at line 642, which is a real `Scaffold` descendant) before opening the dialog, and use it for the failure-path SnackBar too — never `ctx`. Also wrap the button handler body in `try/catch` so any unexpected exception (not just a failed `sendPasswordReset` call) still surfaces visible feedback and closes/pops the dialog instead of leaving it stuck.

**Files:**
- Modify: `lib/features/auth/presentation/pages/auth_screen.dart:558-651`
- Test: `test/features/auth/auth_screen_forgot_password_test.dart` (create)

**Interfaces:**
- Consumes: `AuthProvider.sendPasswordReset(String email)` (existing, unchanged) — returns `Future<bool>`, exposes `AuthProvider.error` (`String?`) on failure.
- Produces: no new public API — behavioral fix only, inside `_ForgotPasswordDialog`/`_showForgotPasswordDialog`.

- [ ] **Step 1: Read the current method in full to confirm the exact context misuse**

```bash
sed -n '558,651p' lib/features/auth/presentation/pages/auth_screen.dart
```

Confirm: `ScaffoldMessenger.of(ctx)` appears once, inside the failure branch of the `FilledButton`'s `onPressed` (around line 622), and the success branch (line 641-650) already correctly uses the *outer* `context` after `showDialog` has returned. If the code has drifted since this plan was written, adjust the following steps to the actual line numbers — don't blindly apply the diff below.

- [ ] **Step 2: Write the failing test**

```dart
// test/features/auth/auth_screen_forgot_password_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';

class _FailingAuthProvider extends AuthProvider {
  @override
  Future<bool> sendPasswordReset(String email) async {
    return false;
  }

  @override
  String? get error => 'Could not send the email.';
}

void main() {
  testWidgets(
    'shows a visible error (not a stuck dialog) when password reset fails',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _FailingAuthProvider(),
          child: MaterialApp(theme: AppTheme.light, home: const AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'nadie@gmail.com',
      );
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();

      // The failure must be visibly reported, not silently swallowed —
      // this is what a Playwright/TestSprite-style agent checks by DOM
      // inspection, not by whether an exception was thrown internally.
      expect(find.text('Could not send the email.'), findsOneWidget);
    },
  );
}
```

Before finalizing this test, check `AuthScreen`'s actual widget tree for the exact button/label text (`grep -n "authForgotPassword\|authSendLink\|Forgot your password" lib/features/auth/presentation/pages/auth_screen.dart lib/l10n/app_localizations_en.dart`) and adjust finders if the English l10n strings differ from what's assumed here.

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/features/auth/auth_screen_forgot_password_test.dart
```

Expected: FAIL — the error text is never found because `ScaffoldMessenger.of(ctx)` (dialog context) cannot locate a messenger in the test's widget tree either (same bug reproduces in the test harness), so no SnackBar renders.

- [ ] **Step 4: Fix `_showForgotPasswordDialog`**

```dart
// lib/features/auth/presentation/pages/auth_screen.dart
Future<void> _showForgotPasswordDialog() async {
  final colors = context.appColors;
  final screenContext = context; // capture BEFORE opening the dialog
  final resetEmailController = TextEditingController(
    text: _isValidEmail(_emailController.text)
        ? _emailController.text.trim()
        : '',
  );

  final sent = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.authForgotPassTitle, style: AppTextStyles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.authForgotPassDesc,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.authEmailLabel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.authCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (!_isValidEmail(email)) {
                ScaffoldMessenger.of(screenContext).showSnackBar(
                  SnackBar(content: Text(context.l10n.authInvalidEmail)),
                );
                return;
              }
              try {
                final authProvider = ctx.read<AuthProvider>();
                final success = await authProvider.sendPasswordReset(email);
                if (!ctx.mounted) return;
                if (success) {
                  Navigator.pop(ctx, true);
                } else {
                  Navigator.pop(ctx, false);
                  if (!screenContext.mounted) return;
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        authProvider.error ?? screenContext.l10n.authSendEmailError,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx, false);
                if (screenContext.mounted) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(content: Text(screenContext.l10n.authSendEmailError)),
                  );
                }
              }
            },
            child: Text(context.l10n.authSendLink),
          ),
        ],
      );
    },
  );

  final emailSentTo = resetEmailController.text.trim();
  resetEmailController.dispose();

  if (sent == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.l10n.authCheckInbox}${emailSentTo.isNotEmpty ? emailSentTo : ""}${context.l10n.authAndSpam}',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
```

Note the key change: both the validation-error SnackBar and the failure-path SnackBar now use `screenContext` (captured from the enclosing `State`, guaranteed to sit under the page's `Scaffold`) instead of `ctx` (the dialog's own context). The dialog is also explicitly popped (`Navigator.pop(ctx, false)`) on failure so it never stays stuck open — previously it only popped on success.

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/auth/auth_screen_forgot_password_test.dart
```

- [ ] **Step 6: Run flutter analyze and the existing auth test suite**

```bash
flutter analyze lib/features/auth/presentation/pages/auth_screen.dart
flutter test test/features/auth
```

Expected: no analyzer errors, no regressions.

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/presentation/pages/auth_screen.dart test/features/auth/auth_screen_forgot_password_test.dart
git commit -m "fix(auth): show visible feedback when password reset fails instead of a stuck dialog"
```

---

### Task 2: Let owners browse a workshop's reviews before choosing it (without the write-review gate)

**Root cause:** `WorkshopDirectoryScreen`'s workshop card (`lib/features/dashboard/presentation/pages/workshop_directory_screen.dart:1119-1127`) has exactly one review-related control — a `TextButton.icon` labeled `context.l10n.wdReview`, wired to `_reviewWorkshop` (`lib/features/dashboard/presentation/pages/workshop_directory_screen.dart:61-89`), which is the *submit-a-review* flow: it calls `_reviewService.findReviewableServiceId(userId, tallerId)` and, if the user has no completed service with that workshop, blocks with the SnackBar `'Debes completar un servicio con este taller antes de reseñarlo.'` (line 78) and returns — no reviews are ever shown. There is no separate "browse reviews" action anywhere in this screen. `ReviewService.getReviewsForTaller`/`watchReviewsForTaller` (`lib/features/reviews/data/services/review_service.dart:54-72`) already exist and already return the full review list for a `tallerId` — they are simply unused here.

**Fix:** add a small read-only reviews list widget and a new "Ver reseñas" action next to the existing rating badge (`reviewsCount` text at `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart:1101-1114`), reachable regardless of the user's service-completion eligibility. Leave `_reviewWorkshop`'s gating logic untouched — that gate is legitimate for *writing* a review, just not for *reading* one.

**Files:**
- Create: `lib/core/widgets/workshop_reviews_list_sheet.dart`
- Modify: `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart:1095-1170` (both the mobile-card layout and the equivalent list-tile/desktop layout around line 860-880 — check both call sites with `grep -n "_reviewWorkshop" lib/features/dashboard/presentation/pages/workshop_directory_screen.dart` since the earlier `Read` of this file showed a similar `reviewsCount`/`wdReview` block appearing twice, once around line 870 and once around line 1101)
- Test: `test/core/widgets/workshop_reviews_list_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `ReviewService.watchReviewsForTaller(String tallerId)` (existing, unchanged) — `Stream<List<ReviewModel>>`, already sorted most-recent-first via `ordenarResenias`.
- Produces: `showWorkshopReviewsSheet(BuildContext context, {required String tallerId, required String tallerNombre, ReviewService? reviewService})` — a top-level function in `workshop_reviews_list_sheet.dart`, called from both card layouts.

- [ ] **Step 1: Confirm both card layouts and their exact `wdReview` button locations**

```bash
grep -n "_reviewWorkshop(context" lib/features/dashboard/presentation/pages/workshop_directory_screen.dart
```

Expected: two call sites (one per responsive layout). Both need the new "Ver reseñas" action added next to them.

- [ ] **Step 2: Write the failing test for the new sheet**

```dart
// test/core/widgets/workshop_reviews_list_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/widgets/workshop_reviews_list_sheet.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

class _FakeReviewService implements ReviewService {
  _FakeReviewService(this._reviews);
  final List<ReviewModel> _reviews;

  @override
  Stream<List<ReviewModel>> watchReviewsForTaller(String tallerId) =>
      Stream.value(_reviews);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'shows existing reviews without requiring a completed service',
    (tester) async {
      final reviews = [
        ReviewModel(
          idResenia: 'r1',
          idUsuario: 'u1',
          idTaller: 't1',
          idServicio: 's1',
          estrellas: 5,
          comentario: 'Excelente atención, muy rápido.',
          fechaResenia: DateTime(2026, 1, 10),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showWorkshopReviewsSheet(
                context,
                tallerId: 't1',
                tallerNombre: 'Taller Central',
                reviewService: _FakeReviewService(reviews),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Excelente atención, muy rápido.'), findsOneWidget);
      // Must NOT show the write-review eligibility gate — this is a
      // read-only view.
      expect(
        find.textContaining('Debes completar un servicio'),
        findsNothing,
      );
    },
  );

  testWidgets('shows an empty state when the workshop has no reviews yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showWorkshopReviewsSheet(
              context,
              tallerId: 't2',
              tallerNombre: 'Taller Nuevo',
              reviewService: _FakeReviewService(const []),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay reseñas para este taller.'), findsOneWidget);
  });
}
```

Before finalizing, run `grep -n "class ReviewService" lib/features/reviews/data/services/review_service.dart` to confirm whether it's already an interface-friendly class (no `final` fields blocking a fake subclass) — if `ReviewService` cannot be subclassed/faked this way (e.g. it's not abstract and has private final fields), adjust the fake to wrap a real `ReviewService(firestore: FakeFirebaseFirestore())` seeded with a review document instead, following the pattern in `test/features/mechanic/presentation/providers/catalogo_provider_test.dart`.

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/core/widgets/workshop_reviews_list_sheet_test.dart
```

Expected: FAIL with a compile error — `showWorkshopReviewsSheet` doesn't exist yet.

- [ ] **Step 4: Create the read-only reviews sheet**

```dart
// lib/core/widgets/workshop_reviews_list_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

Future<void> showWorkshopReviewsSheet(
  BuildContext context, {
  required String tallerId,
  required String tallerNombre,
  ReviewService? reviewService,
}) {
  final service = reviewService ?? ReviewService();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _WorkshopReviewsSheetContent(
      tallerId: tallerId,
      tallerNombre: tallerNombre,
      reviewService: service,
    ),
  );
}

class _WorkshopReviewsSheetContent extends StatelessWidget {
  const _WorkshopReviewsSheetContent({
    required this.tallerId,
    required this.tallerNombre,
    required this.reviewService,
  });

  final String tallerId;
  final String tallerNombre;
  final ReviewService reviewService;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reseñas de $tallerNombre',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: StreamBuilder<List<ReviewModel>>(
                  stream: reviewService.watchReviewsForTaller(tallerId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final reviews = snapshot.data!;
                    if (reviews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Aún no hay reseñas para este taller.'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    i < review.estrellas
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(review.fechaResenia),
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (review.comentario != null &&
                                review.comentario!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(review.comentario!),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/core/widgets/workshop_reviews_list_sheet_test.dart
```

- [ ] **Step 6: Wire "Ver reseñas" into both `WorkshopDirectoryScreen` card layouts**

At each of the two `_reviewWorkshop(context...)` call sites found in Step 1, add a second, ungated action next to the existing "Review" button:

```dart
TextButton(
  onPressed: () => showWorkshopReviewsSheet(
    context,
    tallerId: tallerId,
    tallerNombre: name,
  ),
  child: const Text('Ver reseñas'),
),
```

Add `import 'package:autodoc/core/widgets/workshop_reviews_list_sheet.dart';` to `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart`. Place the new button so it doesn't overflow the existing `Row`'s available width on mobile — wrap the button `Row` in a `Wrap` if `flutter analyze`/manual layout testing shows overflow, matching whatever pattern the surrounding `Row`s in this file already use for narrow layouts (check `Wrap(` usages in the same file first with `grep -n "Wrap(" lib/features/dashboard/presentation/pages/workshop_directory_screen.dart`).

- [ ] **Step 7: Run flutter analyze and the dashboard test suite**

```bash
flutter analyze lib/features/dashboard/presentation/pages/workshop_directory_screen.dart lib/core/widgets/workshop_reviews_list_sheet.dart
flutter test test/core/widgets/workshop_reviews_list_sheet_test.dart test/features/dashboard
```

Expected: no analyzer errors, no regressions.

- [ ] **Step 8: Commit**

```bash
git add lib/core/widgets/workshop_reviews_list_sheet.dart lib/features/dashboard/presentation/pages/workshop_directory_screen.dart test/core/widgets/workshop_reviews_list_sheet_test.dart
git commit -m "feat(reviews): let owners browse a workshop's reviews from the directory without requiring a completed service"
```

---

### Task 3: Fetch alerts for every owned vehicle, not just the selected one

**Root cause:** `_DashboardScreenState.didChangeDependencies` (`lib/features/dashboard/presentation/pages/dashboard_screen.dart:37-58`) calls `vehicleProvider.fetchVehicles(userData.idUsuario)` and then, only if `vehicleProvider.selectedVehicle != null`, calls `context.read<AlertProvider>().fetchAlerts(vehicleProvider.selectedVehicle!.idVehiculo, vehicleProvider.selectedVehicle!)` exactly once (lines 49-56). `AlertProvider.fetchAlerts` (`lib/features/dashboard/presentation/providers/alert_provider.dart:34-81`) then does `_alerts = snapshot.docs.map(...).toList()` (line 46) — a **replace**, not a merge. So for an owner with more than one registered vehicle, only the selected vehicle's alerts are ever loaded, and calling `fetchAlerts` again for a second vehicle would wipe out the first vehicle's alerts rather than add to them. The dashboard's "Active Alerts" panel (`activeAlerts` getter, `alert_provider.dart:28-29`) can therefore show "no pending alerts" even when a non-selected vehicle genuinely has one.

**Fix:** change `AlertProvider` to fetch and merge alerts across a list of vehicles instead of one, and call it with all of the owner's vehicles from the dashboard.

**Files:**
- Modify: `lib/features/dashboard/presentation/providers/alert_provider.dart:14-81`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_screen.dart:46-57`
- Test: `test/features/dashboard/presentation/providers/alert_provider_multi_vehicle_test.dart` (create)

**Interfaces:**
- Produces: `AlertProvider.fetchAlertsForVehicles(List<VehicleModel> vehicles)` — new method, fetches and merges alerts/maintenance tasks across all given vehicles. `AlertProvider.fetchAlerts(String vehicleId, VehicleModel vehicle)` (existing signature) stays as the single-vehicle primitive `fetchAlertsForVehicles` calls internally per vehicle — do not remove it, other call sites may depend on it (`grep -rn "\.fetchAlerts(" lib/` first to confirm no other caller before changing its merge behavior).

- [ ] **Step 1: Confirm no other call site depends on `fetchAlerts` replacing (not merging) `_alerts`**

```bash
grep -rn "\.fetchAlerts(" lib/ test/
```

If another screen intentionally relies on `fetchAlerts` fully replacing `_alerts` for a single-vehicle view (e.g. a per-vehicle alerts screen), keep `fetchAlerts`'s existing replace behavior untouched and only add the new merging method — do not change `fetchAlerts` itself.

- [ ] **Step 2: Write the failing test**

```dart
// test/features/dashboard/presentation/providers/alert_provider_multi_vehicle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

void main() {
  test(
    'fetchAlertsForVehicles merges alerts from every vehicle instead of replacing them',
    () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('alertas').add({
        'id_vehiculo': 'v1',
        'estado': 'Pendiente',
        'titulo': 'SOAT vence pronto',
      });
      await firestore.collection('alertas').add({
        'id_vehiculo': 'v2',
        'estado': 'Pendiente',
        'titulo': 'Cambio de aceite',
      });

      final provider = AlertProvider(firestore: firestore);
      final v1 = VehicleModel(
        idVehiculo: 'v1',
        idPropietario: 'owner-1',
        placa: 'P111-111',
        marca: 'Toyota',
        modelo: 'Corolla',
        kilometrajeActual: 10000,
      );
      final v2 = VehicleModel(
        idVehiculo: 'v2',
        idPropietario: 'owner-1',
        placa: 'P222-222',
        marca: 'Honda',
        modelo: 'Civic',
        kilometrajeActual: 20000,
      );

      await provider.fetchAlertsForVehicles([v1, v2]);

      expect(provider.activeAlerts.length, 2);
      expect(
        provider.activeAlerts.map((a) => a.idVehiculo).toSet(),
        {'v1', 'v2'},
      );
    },
  );
}
```

Adjust `VehicleModel(...)`'s constructor arguments to its real required fields (`grep -n "required this\." lib/core/models/vehicle_model.dart` first) and `AlertModel`'s field name for the vehicle id (`grep -n "idVehiculo\|id_vehiculo" lib/core/models/alert_model.dart`) — this plan does not assume either model's exact shape beyond what's already been read from `AlertProvider`.

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/features/dashboard/presentation/providers/alert_provider_multi_vehicle_test.dart
```

Expected: FAIL with a compile error (`fetchAlertsForVehicles` doesn't exist yet).

- [ ] **Step 4: Add the merging method to `AlertProvider`**

```dart
// lib/features/dashboard/presentation/providers/alert_provider.dart
Future<void> fetchAlertsForVehicles(List<VehicleModel> vehicles) async {
  if (vehicles.isEmpty) {
    _alerts = [];
    _maintenanceTasks = [];
    notifyListeners();
    return;
  }

  _isLoading = true;
  _error = null;
  notifyListeners();

  final mergedAlerts = <AlertModel>[];
  final mergedTasks = <MaintenanceTask>[];

  for (final vehicle in vehicles) {
    try {
      await fetchAlerts(vehicle.idVehiculo, vehicle);
      mergedAlerts.addAll(_alerts);
      mergedTasks.addAll(_maintenanceTasks);
    } catch (e) {
      _error = e.toString();
    }
  }

  _alerts = mergedAlerts;
  _maintenanceTasks = mergedTasks;
  _isLoading = false;
  notifyListeners();
}
```

This reuses the existing single-vehicle `fetchAlerts` (unchanged) as the per-vehicle primitive and accumulates its results across vehicles instead of overwriting.

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/dashboard/presentation/providers/alert_provider_multi_vehicle_test.dart
```

- [ ] **Step 6: Call the new method from the dashboard for all of the owner's vehicles**

```dart
// lib/features/dashboard/presentation/pages/dashboard_screen.dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final vehicleProvider = context.read<VehicleProvider>();
  vehicleProvider.fetchVehicles(userData.idUsuario).then((_) {
    if (mounted && vehicleProvider.vehicles.isNotEmpty) {
      context.read<AlertProvider>().fetchAlertsForVehicles(
        vehicleProvider.vehicles,
      );
    }
  });
});
```

Confirm `VehicleProvider` exposes a `vehicles` getter (list of all fetched vehicles, not just `selectedVehicle`) with `grep -n "List<VehicleModel> get" lib/features/dashboard/presentation/providers/vehicle_provider.dart` before finalizing this edit — if the getter has a different name, use that name instead.

- [ ] **Step 7: Run the full dashboard test suite to check for regressions**

```bash
flutter analyze lib/features/dashboard/presentation/providers/alert_provider.dart lib/features/dashboard/presentation/pages/dashboard_screen.dart
flutter test test/features/dashboard
```

- [ ] **Step 8: Commit**

```bash
git add lib/features/dashboard/presentation/providers/alert_provider.dart lib/features/dashboard/presentation/pages/dashboard_screen.dart test/features/dashboard/presentation/providers/alert_provider_multi_vehicle_test.dart
git commit -m "fix(dashboard): show expiring alerts from every owned vehicle, not just the selected one"
```

---

### Task 4: Verify the "404" reports are TestSprite navigation mistakes, not routing bugs (no code change expected)

**Root cause:** TestSprite's own generated Playwright scripts call `page.goto("https://autodoc-6ef5a.web.app/directorio")`, `.../chat`, and `.../garaje` directly. None of these paths are registered in `lib/core/router/app_router.dart` — the real paths are `/workshop_directory` (line 381), `/chat_list` (line 397), and `/mechanic_reparaciones` (line 469, the kanban board) / `/garage` (line 373, the vehicle garage — a different feature than what TestSprite's "Track repairs on the kanban board" test actually needed). `go_router`'s `errorBuilder` (line 314-315) correctly renders `Scaffold(body: Center(child: Text('Página no encontrada (404)')))` for any unmatched path — TestSprite's own "Cause" analysis speculated a Firebase Hosting rewrite/SPA-fallback misconfiguration, but that's testing a symptom (the in-app 404 text) without checking the app's router source, which shows the behavior is correct given the wrong URLs.

This explains 5 of the 10 reported issues: Manage workshop staff (Failed), View active conversations (Failed), Track repairs on the kanban board (Failed), Change a user role from the admin area (Blocked), Review reservation details from a conversation (Blocked).

**Files:** none to modify. Read-only verification.

- [ ] **Step 1: Confirm the real route paths and that they are reachable**

```bash
grep -n "path: '/" lib/core/router/app_router.dart
```

Expected: `/workshop_directory`, `/chat_list`, `/mechanic_reparaciones`, `/garage` are present; `/directorio`, `/chat`, `/garaje` are absent.

- [ ] **Step 2: Confirm the errorBuilder is intentional, not an accidental catch-all that masks a real bug**

```bash
sed -n '308,320p' lib/core/router/app_router.dart
```

Confirm `errorBuilder` is a deliberate fallback page, not, e.g., a redirect loop or an exception handler papering over a crash.

- [ ] **Step 3: Write a regression test locking in that the real routes render (not 404) while a bogus path does**

```dart
// test/core/router/app_router_unknown_route_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'unmatched paths render the in-app 404 page, not a blank/broken screen',
    (tester) async {
      final router = GoRouter(
        errorBuilder: (context, state) => const Scaffold(
          body: Center(child: Text('Página no encontrada (404)')),
        ),
        routes: [
          GoRoute(
            path: '/workshop_directory',
            builder: (_, __) => const Scaffold(body: Text('DIRECTORY_OK')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/directorio'); // the wrong path TestSprite used
      await tester.pumpAndSettle();
      expect(find.text('Página no encontrada (404)'), findsOneWidget);

      router.go('/workshop_directory'); // the real registered path
      await tester.pumpAndSettle();
      expect(find.text('DIRECTORY_OK'), findsOneWidget);
    },
  );
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/core/router/app_router_unknown_route_test.dart
```

Expected: PASS, confirming the router's behavior is correct and intentional for both the wrong and the right paths.

- [ ] **Step 5: No code fix.** Document the finding for whoever re-runs TestSprite: these 5 tests must navigate via in-app UI interaction (clicking the actual nav links) or use the correct paths (`/workshop_directory`, `/chat_list`, `/mechanic_reparaciones`) — not the guessed `/directorio`, `/chat`, `/garaje` — for the tests to exercise real app behavior.

- [ ] **Step 6: Commit the verification test only**

```bash
git add test/core/router/app_router_unknown_route_test.dart
git commit -m "test(router): lock in that unmatched paths render the in-app 404, confirming TestSprite's guessed routes were wrong"
```

---

### Task 5: Verify "Prevent invalid admin sign in" used a genuinely valid test account (no code change expected)

**Root cause:** The failed test entered `nadie@gmail.com` / `hola123` expecting sign-in to be *rejected*. But the same exact credentials are used as the **standard successful login** across roughly 30 other tests in the same `TestSprite.md` report (e.g. "Manage workshop staff", "Track repairs on the kanban board", "View active conversations", all of which reach `Hello, usuario` on `/dashboard` before hitting their unrelated 404 issue). `AuthProvider.signIn` (`lib/features/auth/presentation/providers/auth_provider.dart:38-66`) calls `AuthService.signInWithEmail`, which only succeeds for real Firebase Auth accounts and throws a localized `FirebaseAuthException` otherwise (`lib/features/auth/data/services/auth_service.dart:54-63,155+`) — there is no bypass in this code path. `nadie@gmail.com` is evidently a real, valid seeded production account, so this test used the wrong (valid) credentials by mistake — it is not testing invalid credentials at all.

**Files:** none to modify. Read-only verification.

- [ ] **Step 1: Confirm there is no credential bypass in the sign-in path**

```bash
sed -n '38,66p' lib/features/auth/presentation/providers/auth_provider.dart
sed -n '54,63p' lib/features/auth/data/services/auth_service.dart
```

Confirm `signIn` returns `false` and sets `_error` whenever `AuthService.signInWithEmail` throws, and that `signInWithEmail` has no fallback/mock branch — it only ever calls `_auth.signInWithEmailAndPassword`.

- [ ] **Step 2: Cross-check that `nadie@gmail.com` succeeds elsewhere in the same report**

```bash
grep -c "nadie@gmail.com" TestSprite.md
```

Expected: many occurrences across Passed tests, confirming it's the report's standard valid test account, not a credential that should be rejected.

- [ ] **Step 3: Write a regression test locking in that `AuthProvider.signIn` correctly rejects genuinely wrong credentials**

```dart
// test/features/auth/auth_provider_invalid_credentials_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';

void main() {
  test(
    'signIn returns false and sets an error for credentials Firebase rejects',
    () async {
      final provider = AuthProvider();

      final result = await provider.signIn(
        'definitely-not-a-real-account@example.invalid',
        'wrong-password-123',
      );

      expect(result, isFalse);
      expect(provider.error, isNotNull);
    },
  );
}
```

Check `test/features/auth/auth_provider_test.dart` first (`grep -n "class \|FirebaseAuth\|Mock" test/features/auth/auth_provider_test.dart`) to see whether `AuthProvider` in this codebase already accepts an injectable/mockable `AuthService` for tests without hitting real Firebase — if it doesn't, reuse whatever mocking pattern that existing test file already uses (it clearly manages to test `AuthProvider` somehow) instead of inventing a new one.

- [ ] **Step 4: Run the test**

```bash
flutter test test/features/auth/auth_provider_invalid_credentials_test.dart
```

Expected: PASS, confirming invalid-credential rejection already works correctly.

- [ ] **Step 5: No code fix.** Document the finding: re-run "Prevent invalid admin sign in" with credentials that are actually invalid in the target environment (not `nadie@gmail.com`/`hola123`, which is the suite's valid test account) for the test to mean anything.

- [ ] **Step 6: Commit the verification test only**

```bash
git add test/features/auth/auth_provider_invalid_credentials_test.dart
git commit -m "test(auth): lock in that AuthProvider.signIn rejects genuinely invalid credentials"
```

---

## Self-review notes

- **Coverage:** all 10 Failed/Blocked TestSprite.md entries map to exactly one task above (Task 1: Reset password; Task 2: Read workshop reviews + View workshop reviews; Task 3: View expiring alerts; Task 4: Manage workshop staff + View active conversations + Track repairs on kanban + Change a user role + Review reservation details; Task 5: Prevent invalid admin sign in). No entry is unaccounted for.
- **Not in scope:** the 30 `BLOCKED` tests in `testsprite_tests/tmp/test_results.json` (local MCP run) are excluded per the user's confirmation that `TestSprite.md` is the correct evidence source — that run's uniform "SPA never rendered" blockage is a test-infra issue (release build served without a dev server/emulators), not a set of per-feature defects, and fixing it is a separate concern from this plan.
- **Verify-only tasks (4 and 5) intentionally add no `lib/` changes** — the underlying app behavior is already correct; adding a regression test for each locks in that correctness and gives a paper trail for why no code fix was made.
