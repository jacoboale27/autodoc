import 'package:flutter/material.dart';

import 'package:autodoc/l10n/app_localizations.dart';

/// Shown when Firebase Core cannot start, before any Firebase service is used.
///
/// UX-02: the screen used to tell the user to reload the page without giving
/// them any way to do it. It now owns a retry control. The failure cause is
/// deliberately never rendered — it goes to the debug log only, so the user
/// sees recovery instructions instead of a raw exception.
class FirebaseInitializationErrorScreen extends StatefulWidget {
  const FirebaseInitializationErrorScreen({super.key, this.onRetry});

  /// Re-runs the startup sequence and reports whether it succeeded. On
  /// success the caller is expected to replace this app with the real one, so
  /// a `true` that comes back here simply leaves the screen as it was. Null
  /// disables the retry control, which is only the case in tests that
  /// exercise the static copy.
  final Future<bool> Function()? onRetry;

  @override
  State<FirebaseInitializationErrorScreen> createState() =>
      _FirebaseInitializationErrorScreenState();
}

class _FirebaseInitializationErrorScreenState
    extends State<FirebaseInitializationErrorScreen> {
  bool _retrying = false;
  bool _retryFailed = false;

  Future<void> _handleRetry() async {
    final retry = widget.onRetry;
    // Guard against a second tap landing while the first attempt is in
    // flight: two concurrent Firebase bootstraps is exactly the
    // 'duplicate-app' case main.dart already has to paper over.
    if (retry == null || _retrying) return;

    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    try {
      final recovered = await retry();
      if (mounted && !recovered) setState(() => _retryFailed = true);
    } catch (_) {
      // The cause is not shown to the user by design; a failed retry only
      // changes the copy so they know the attempt happened and failed.
      if (mounted) setState(() => _retryFailed = true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56),
                const SizedBox(height: 20),
                Text(
                  l10n.startupErrorTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.startupErrorBody, textAlign: TextAlign.center),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    enabled: !_retrying,
                    child: FilledButton(
                      onPressed: _retrying ? null : _handleRetry,
                      child: _retrying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.startupErrorRetry),
                    ),
                  ),
                ],
                if (_retryFailed && !_retrying) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.startupErrorRetryFailed,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirebaseInitializationErrorApp extends StatelessWidget {
  const FirebaseInitializationErrorApp({super.key, this.onRetry});

  final Future<bool> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FirebaseInitializationErrorScreen(onRetry: onRetry),
    );
  }
}
