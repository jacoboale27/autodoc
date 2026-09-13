import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import '../providers/auth_provider.dart';

/// All navigation decisions remain in the router, including leaving this gate.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.authSendEmailError)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<AuthSessionProvider>();
    final auth = context.read<AuthProvider>();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 48),
                    const SizedBox(height: 24),
                    Text(
                      l10n.authVerifyEmailTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.authAccountNotVerified),
                    Text(session.user?.email ?? ''),
                    const SizedBox(height: 16),
                    Text(l10n.authOpenLinkThenVerify),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              // reload(), session update and notifyListeners() happen
                              // in that order; the router then reevaluates access.
                              await session.refreshUser();
                              return session.error == null &&
                                      session.user?.emailVerified == true
                                  ? null
                                  : l10n.authVerificationNotDetected;
                            }),
                      child: Text(l10n.authAlreadyVerified),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final sent = await auth.sendEmailVerification();
                              return sent
                                  ? l10n.authEmailResent
                                  : l10n.authResendError;
                            }),
                      child: Text(l10n.authResendEmail),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await auth.signOut();
                              return null;
                            }),
                      child: Text(l10n.upSignOut),
                    ),
                    if (_busy) const Center(child: CircularProgressIndicator()),
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
