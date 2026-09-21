import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter/services.dart';

import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/logger.dart';
import 'views/splash_animation_view.dart';

/// Pantalla de Splash corporativa basada en video de introducción a pantalla completa.
///
/// Reproduce el video corporativo (`assets/estilo_neutral.mp4`), maneja el ciclo de
/// vida del [VideoPlayerController], tolerancia a fallas y navega automáticamente
/// al finalizar sin comprobación de sesión.
class SplashScreen extends StatefulWidget {
  /// Ruta del recurso de video en assets.
  final String videoAsset;

  /// Callback configurable al finalizar la reproducción del video.
  /// Si es nulo, navega por defecto a [RoutePaths.login] mediante go_router.
  final VoidCallback? onVideoFinished;

  /// Controlador inyectado opcionalmente (útil para pruebas unitarias y de widgets).
  final VideoPlayerController? controller;

  /// Color de fondo corporativo de la pantalla (por defecto el tono arena de assets/icon.png).
  final Color? backgroundColor;

  /// Modo de ajuste de la capa visible del video (por defecto BoxFit.contain
  /// para no recortar el logo, que llega casi hasta los bordes del cuadro).
  final BoxFit videoFit;

  /// Crea una instancia de [SplashScreen].
  const SplashScreen({
    super.key,
    this.videoAsset = 'assets/estilo_neutral.mp4',
    this.onVideoFinished,
    this.controller,
    this.backgroundColor,
    this.videoFit = BoxFit.contain,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _hasNavigated = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = widget.controller ??
          VideoPlayerController.asset(widget.videoAsset);

      _controller = controller;
      await controller.initialize();

      if (!mounted) return;

      // Remover splash nativo una vez renderizado el primer frame
      FlutterNativeSplash.remove();

      controller.addListener(_onVideoProgress);
      await controller.setVolume(1.0);
      await controller.play();

      setState(() {
        _isInitialized = true;
      });
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al inicializar el video de splash (${widget.videoAsset})',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );

      // Resiliencia: ante cualquier falla de formato o carga, navegar de inmediato
      if (mounted) {
        FlutterNativeSplash.remove();
        _navigateToNext();
      }
    }
  }

  void _onVideoProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final value = controller.value;

    // Detectar error de reproducción en tiempo real
    if (value.hasError) {
      Logger.error(
        'Error durante la reproducción del video de splash: ${value.errorDescription}',
      );
      _navigateToNext();
      return;
    }

    // Detectar finalización de la reproducción
    if (value.position >= value.duration && value.duration > Duration.zero) {
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    if (widget.onVideoFinished != null) {
      widget.onVideoFinished!();
    } else {
      context.go(RoutePaths.login);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _controller?.removeListener(_onVideoProgress);
    if (widget.controller == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor =
        widget.backgroundColor ?? AppPalette.splashBackground;

    return Scaffold(
      backgroundColor: effectiveBgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo degradado continuo corporativo armonizado con el video
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE8E0D2), // Tono superior del video
                  effectiveBgColor, // Color institucional (#D4C7B4)
                  const Color(0xFFBCAA96), // Tono inferior del video
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Capa de video adaptativa por tipo de dispositivo sin estiramiento
          if (_isInitialized && _controller != null)
            SplashAnimationView(
              controller: _controller!,
              fit: widget.videoFit,
            ),

          // Botón accesible de "Omitir" en esquina superior
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            child: Semantics(
              button: true,
              label: 'Omitir video de introducción',
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.textPrimary,
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppPalette.border),
                  ),
                ),
                onPressed: _navigateToNext,
                icon: const Icon(
                  CupertinoIcons.forward,
                  size: 14,
                  color: AppPalette.textPrimary,
                ),
                label: const Text(
                  'Omitir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
