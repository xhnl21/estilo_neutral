import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../application/auth_notifier.dart';

/// Pantalla de inicio de sesión de Estilo Neutral.
class LoginPage extends StatefulWidget {
  final AuthNotifier authNotifier;

  const LoginPage({super.key, required this.authNotifier});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController =
      TextEditingController(text: 'admin@estiloneutral.com');
  final TextEditingController _passwordController =
      TextEditingController(text: '********');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    widget.authNotifier.login(email: _emailController.text);
    final String? from = GoRouterState.of(context).uri.queryParameters['from'];
    if (from != null && from.isNotEmpty) {
      context.go(from);
    } else {
      context.go(RoutePaths.ventas);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppPalette.blue100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.lock_shield,
                        color: AppPalette.blue900,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Iniciar Sesión',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Acceso al sistema Estilo Neutral (Google Sheets ORM)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: 'Correo Electrónico',
                    controller: _emailController,
                    prefixIcon: CupertinoIcons.mail,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Contraseña',
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: CupertinoIcons.lock,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Ingresar al Sistema',
                    icon: CupertinoIcons.arrow_right,
                    onPressed: _handleLogin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
