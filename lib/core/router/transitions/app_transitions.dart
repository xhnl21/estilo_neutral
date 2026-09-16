import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transiciones reutilizables para rutas de go_router.
abstract class AppTransitions {
  /// Transición con desvanecimiento suave (fade).
  static CustomTransitionPage<T> fade<T>({
    required LocalKey key,
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
    );
  }

  /// Transición deslizante desde la derecha (slide horizontal).
  static CustomTransitionPage<T> slide<T>({
    required LocalKey key,
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
