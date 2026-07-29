import 'package:flutter/material.dart';
import '../pages/auth_screen.dart';

/// Responsive Login Screen for AutoDoc (Landscape and Wide screens compatible).
///
/// Wraps the login layout with a [SingleChildScrollView] and [ConstrainedBox]
/// to prevent visual overflow in landscape mode.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(isLogin: true);
  }
}
