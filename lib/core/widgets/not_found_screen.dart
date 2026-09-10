import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:autodoc/l10n/app_localizations.dart';

/// UX-02: the router's 404. Replaces a bare centred literal that left the user
/// with no way out and no idea which address had failed.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.attemptedPath});

  /// The path the user actually asked for. Shown back to them because it is
  /// their own input — typo or stale bookmark — and it is the one piece of
  /// context that makes the page actionable.
  final String attemptedPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canGoBack = Navigator.of(context).canPop();

    // Telemetry stays local and carries only the route, never query values,
    // which is where ids and tokens would ride along.
    debugPrint('[AutoDoc][404] unmatched route: $attemptedPath');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_off_rounded, size: 56),
                    const SizedBox(height: 20),
                    Text(
                      l10n.notFoundTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.notFoundBody, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      attemptedPath,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      child: FilledButton(
                        onPressed: () => context.go('/'),
                        child: Text(l10n.notFoundGoHome),
                      ),
                    ),
                    if (canGoBack) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        button: true,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.notFoundGoBack),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
