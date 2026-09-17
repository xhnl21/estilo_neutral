import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Vista desacoplada responsable de renderizar el video de splash
/// a pantalla completa (edge-to-edge) cubriendo el 100% del viewport
/// sin deformaciones ni franjas negras (similar a BoxFit.cover).
class SplashAnimationView extends StatelessWidget {
  /// Controlador del reproductor de video inicializado.
  final VideoPlayerController controller;

  /// Modo de ajuste de escala del video (por defecto BoxFit.cover para llenar toda la pantalla).
  final BoxFit fit;

  /// Crea la vista de animación del video de splash.
  const SplashAnimationView({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
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

    // return SizedBox.expand(
    //   child: FittedBox(
    //     fit: fit,
    //     child: SizedBox(
    //       width: width,
    //       height: height,
    //       child: VideoPlayer(controller),
    //     ),
    //   ),
    // );
    // return Container(
    //   color: const Color(
    //       0xFFE6DCCF), // Reemplaza con el color exacto del fondo de tu video
    //   child: SizedBox.expand(
    //     child: FittedBox(
    //       fit: BoxFit.contain, // Muestra todo el video sin recortar
    //       child: SizedBox(
    //         width: width,
    //         height: height,
    //         child: VideoPlayer(controller),
    //       ),
    //     ),
    //   ),
    // );
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo desenfocado (llena toda la pantalla)
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.3), // Oscurece un poco el fondo
                BlendMode.darken,
              ),
              child: VideoPlayer(controller),
            ),
          ),
        ),
        // 2. Video original centrado (se ve completo)
        Center(
          child: FittedBox(
            fit: BoxFit.contain,
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
