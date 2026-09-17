import 'package:estilo_neutral/presentation/screens/splash/views/splash_animation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

class _MockVideoPlayerController extends VideoPlayerController {
  _MockVideoPlayerController(VideoPlayerValue initialValue)
      : super.asset('assets/estilo_neutral.mp4') {
    value = initialValue;
  }
}

void main() {
  group('SplashAnimationView Tests', () {
    testWidgets('renders SizedBox.shrink when controller is not initialized', (tester) async {
      final controller = VideoPlayerController.asset('assets/estilo_neutral.mp4');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplashAnimationView(controller: controller),
          ),
        ),
      );

      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('renders edge-to-edge background cover and foreground contain by default', (tester) async {
      final controller = _MockVideoPlayerController(
        const VideoPlayerValue(
          duration: Duration(seconds: 5),
          size: Size(1080, 1920),
          isInitialized: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplashAnimationView(controller: controller),
          ),
        ),
      );

      final fittedBoxes = tester.widgetList<FittedBox>(find.byType(FittedBox)).toList();
      expect(fittedBoxes.length, equals(2));
      // Capa de fondo: cover
      expect(fittedBoxes.first.fit, equals(BoxFit.cover));
      // Capa de primer plano: contain
      expect(fittedBoxes.last.fit, equals(BoxFit.contain));

      final videoPlayerFinder = find.byType(VideoPlayer);
      expect(videoPlayerFinder, findsNWidgets(2));
    });

    testWidgets('renders ColorFiltered backdrop overlay', (tester) async {
      final controller = _MockVideoPlayerController(
        const VideoPlayerValue(
          duration: Duration(seconds: 5),
          size: Size(1080, 1920),
          isInitialized: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplashAnimationView(controller: controller),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsOneWidget);
    });
  });
}
