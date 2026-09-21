import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Vista desacoplada responsable de renderizar el video de splash
/// a pantalla completa (edge-to-edge) cubriendo el 100% del viewport
/// sin deformaciones ni franjas negras.
///
/// El logo/texto del video llega casi hasta los bordes del cuadro, por lo
/// que no se puede usar [BoxFit.cover] directamente sin recortarlo. En su
/// lugar se compone en dos capas:
/// 1. Un fondo a pantalla completa ([BoxFit.cover]) del mismo video,
///    oscurecido, que rellena los espacios sobrantes sin franjas negras.
/// 2. El video visible con [fit] (por defecto [BoxFit.contain]) centrado,
///    mostrando siempre el cuadro completo sin recortar el logo.
class SplashAnimationView extends StatelessWidget {
  /// Controlador del reproductor de video inicializado.
  final VideoPlayerController controller;

  /// Modo de ajuste de escala de la capa visible del video (por defecto
  /// BoxFit.contain para no recortar el logo).
  final BoxFit fit;

  /// Crea la vista de animación del video de splash.
  const SplashAnimationView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final videoValue = controller.value;

    if (!videoValue.isInitialized) {
      return const SizedBox.shrink();
    }

    final videoSize = videoValue.size;
    final width = videoSize.width > 0 ? videoSize.width : 1080.0;
    final height = videoSize.height > 0 ? videoSize.height : 1920.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo a pantalla completa: rellena los bordes sin franjas negras.
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.3),
                BlendMode.darken,
              ),
              child: VideoPlayer(controller),
            ),
          ),
        ),
        // 2. Video visible completo, sin recortar el logo/texto.
        Center(
          child: FittedBox(
            fit: fit,
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ],
    );
  }
}
