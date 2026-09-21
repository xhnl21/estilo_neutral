import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/access_control_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/logger.dart';
import '../../../../models/models.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_notifier.dart';

/// Pantalla de inicio de sesión de Estilo Neutral mediante Google Sign-In.
class LoginPage extends StatefulWidget {
  final AuthNotifier authNotifier;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;

  const LoginPage({
    super.key,
    required this.authNotifier,
    required this.sheetsAuth,
    required this.dataService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final account = await widget.sheetsAuth.signIn();
      if (!mounted) return;

      if (account == null) {
        // El usuario canceló el selector de cuentas de Google.
        setState(() => _isSigningIn = false);
        return;
      }

      if (!AccessControlConfig.isEmailAllowed(account.email)) {
        Logger.warning(
          'Intento de login con cuenta no autorizada: ${account.email}',
        );
        await widget.sheetsAuth.signOut();
        if (!mounted) return;
        setState(() {
          _isSigningIn = false;
          _errorMessage =
              'La cuenta ${account.email} no tiene acceso a este sistema. '
              'Contactá al administrador si creés que es un error.';
        });
        return;
      }

      final normalizedEmail = account.email.trim().toLowerCase();
      final usuario = widget.dataService.usuarios.firstWhere(
        (u) => u.email == normalizedEmail,
        orElse: () => Usuario(email: normalizedEmail, organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768'),
      );
      widget.dataService.setCurrentOrganizacion(usuario.organizacionId);
      widget.authNotifier.login(email: account.email, organizacionId: usuario.organizacionId);
      final String? from = GoRouterState.of(context).uri.queryParameters['from'];
      if (from != null && from.isNotEmpty) {
        context.go(from);
      } else {
        context.go(RoutePaths.ventas);
      }
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al iniciar sesión con Google',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _errorMessage = 'No se pudo iniciar sesión con Google. Intenta nuevamente.';
      });
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
                    child: ExcludeSemantics(
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
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      'Iniciar Sesión',
                      style: AppTypography.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
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
                  AppButton(
                    label: 'Continuar con Google',
                    icon: CupertinoIcons.globe,
                    isLoading: _isSigningIn,
                    isFullWidth: true,
                    onPressed: _handleGoogleSignIn,
                    semanticHint:
                        'Abre el selector de cuentas de Google para iniciar sesión',
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppPalette.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
