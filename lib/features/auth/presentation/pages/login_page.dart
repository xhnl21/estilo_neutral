import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/auth/biometric_auth_service.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_cubit.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

/// Describe qué botón mostrar y qué va a pasar al tocarlo, para que el
/// usuario tenga claro de antemano si va a elegir una cuenta de Google o
/// solo confirmar con un método ya configurado.
class _AccionLogin {
  final IconData icon;
  final String label;
  final String? caption;

  const _AccionLogin({required this.icon, required this.label, this.caption});
}

/// Pantalla de inicio de sesión de Estilo Neutral.
///
/// La cuenta de Google se elige de forma interactiva la primera vez, y
/// también después de cerrar sesión explícitamente **si la organización no
/// tiene ningún método de Seguridad activo** (ver `MainShell._handleLogout`).
/// En cualquier otro caso (aperturas normales de la app, o después de cerrar
/// sesión teniendo un método activo) la app restaura la sesión de Google en
/// silencio y, si hay un método adicional configurado en Seguridad, muestra
/// su ícono propio (Biométrico, Face ID o 2FA) para que quede claro qué va a
/// pedir antes de tocarlo — sin volver a mostrar el selector de cuentas.
class LoginPage extends StatelessWidget {
  final AuthCubit authCubit;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;
  final BiometricAuthService biometricAuthService;

  LoginPage({
    super.key,
    required this.authCubit,
    required this.sheetsAuth,
    required this.dataService,
    BiometricAuthService? biometricAuthService,
  }) : biometricAuthService = biometricAuthService ?? BiometricAuthService();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(
        authCubit: authCubit,
        sheetsAuth: sheetsAuth,
        dataService: dataService,
        biometricAuthService: biometricAuthService,
      )..restaurarSesion(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  static _AccionLogin _accionPara(String? metodoPendiente) {
    switch (metodoPendiente) {
      case 'biometrico':
        return const _AccionLogin(
          icon: CupertinoIcons.hand_raised_fill,
          label: 'Verificar con Biométrico',
          caption: 'Tu organización activó el desbloqueo por huella dactilar. Tocá para confirmarlo e ingresar.',
        );
      case 'desbloqueo_facial':
        return const _AccionLogin(
          icon: CupertinoIcons.person_crop_circle_fill,
          label: 'Verificar con Face ID',
          caption: 'Tu organización activó el desbloqueo facial. Tocá para confirmarlo con Face ID e ingresar.',
        );
      case 'dos_factores':
        return const _AccionLogin(
          icon: CupertinoIcons.lock_rotation,
          label: 'Verificar con 2FA',
          caption: 'Tu organización activó verificación en dos pasos. Tocá para confirmarlo e ingresar.',
        );
      default:
        return const _AccionLogin(
          icon: CupertinoIcons.globe,
          label: 'Continuar con Google',
          caption: 'La primera vez, ingresá con tu cuenta de Google. Las próximas veces vas a poder '
              'confirmar con Biométrico, Face ID o 2FA si tu organización lo activó en Seguridad.',
        );
    }
  }

  void _navegarTrasLogin(BuildContext context) {
    final String? from = GoRouterState.of(context).uri.queryParameters['from'];
    context.go(from != null && from.isNotEmpty ? from : RoutePaths.ventas);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.status == LoginStatus.autenticado,
      listener: (context, _) => _navegarTrasLogin(context),
      builder: (context, state) => _buildContenido(context, state),
    );
  }

  Widget _buildContenido(BuildContext context, LoginState state) {
    final accion = _accionPara(state.metodoPendiente);

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
                        child: Icon(
                          state.metodoPendiente != null ? accion.icon : CupertinoIcons.lock_shield,
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
                    accion.caption ?? 'Acceso al sistema Estilo Neutral (Google Sheets ORM)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (state.showButton)
                    AppButton(
                      label: accion.label,
                      icon: accion.icon,
                      isLoading: state.isBusy,
                      isFullWidth: true,
                      onPressed: context.read<LoginCubit>().accionPrincipal,
                      semanticHint: accion.caption,
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.errorMessage!,
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
