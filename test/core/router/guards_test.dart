import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:estilo_neutral/core/router/guards/auth_guard.dart';
import 'package:estilo_neutral/core/router/guards/onboarding_guard.dart';
import 'package:estilo_neutral/core/router/route_paths.dart';
import 'package:estilo_neutral/features/auth/application/auth_notifier.dart';
import 'package:estilo_neutral/features/auth/domain/auth_state.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

GoRouterState _createFakeState({required String matchedLocation, Map<String, String>? queryParams}) {
  final uri = Uri(path: matchedLocation, queryParameters: queryParams);
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())]);
  return GoRouterState(
    router.configuration,
    uri: uri,
    matchedLocation: matchedLocation,
    fullPath: matchedLocation,
    pathParameters: const {},
    pageKey: const ValueKey('fake'),
  );
}


void main() {
  group('AuthGuard Tests', () {
    late AuthNotifier authNotifier;
    late AuthGuard authGuard;
    final context = _FakeBuildContext();

    setUp(() {
      authNotifier = AuthNotifier();
      authGuard = AuthGuard(authNotifier: authNotifier);
    });

    test('permits access to /login when unauthenticated', () {
      authNotifier.setState(const AuthState(isAuthenticated: false));
      final state = _createFakeState(matchedLocation: RoutePaths.login);

      final redirect = authGuard.redirect(context, state);
      expect(redirect, isNull);
    });

    test('permits access to /onboarding when unauthenticated', () {
      authNotifier.setState(const AuthState(isAuthenticated: false));
      final state = _createFakeState(matchedLocation: RoutePaths.onboarding);

      final redirect = authGuard.redirect(context, state);
      expect(redirect, isNull);
    });

    test('redirects to /login?from=/clientes when unauthenticated accessing private route', () {
      authNotifier.setState(const AuthState(isAuthenticated: false));
      final state = _createFakeState(matchedLocation: RoutePaths.clientes);

      final redirect = authGuard.redirect(context, state);
      expect(redirect, equals('${RoutePaths.login}?from=%2Fclientes'));
    });

    test('redirects from /login to /ventas when already authenticated', () {
      authNotifier.setState(const AuthState(isAuthenticated: true));
      final state = _createFakeState(matchedLocation: RoutePaths.login);

      final redirect = authGuard.redirect(context, state);
      expect(redirect, equals(RoutePaths.ventas));
    });

    test('redirects from /login to custom previous path via ?from= param', () {
      authNotifier.setState(const AuthState(isAuthenticated: true));
      final state = _createFakeState(
        matchedLocation: RoutePaths.login,
        queryParams: {'from': RoutePaths.inventario},
      );

      final redirect = authGuard.redirect(context, state);
      expect(redirect, equals(RoutePaths.inventario));
    });

    test('permits access to private route when authenticated', () {
      authNotifier.setState(const AuthState(isAuthenticated: true));
      final state = _createFakeState(matchedLocation: RoutePaths.ventas);

      final redirect = authGuard.redirect(context, state);
      expect(redirect, isNull);
    });
  });

  group('OnboardingGuard Tests', () {
    late AuthNotifier authNotifier;
    late OnboardingGuard onboardingGuard;
    final context = _FakeBuildContext();

    setUp(() {
      authNotifier = AuthNotifier();
      onboardingGuard = OnboardingGuard(authNotifier: authNotifier);
    });

    test('does not redirect unauthenticated users (delegates to AuthGuard)', () {
      authNotifier.setState(const AuthState(isAuthenticated: false, isOnboarded: false));
      final state = _createFakeState(matchedLocation: RoutePaths.ventas);

      final redirect = onboardingGuard.redirect(context, state);
      expect(redirect, isNull);
    });

    test('redirects authenticated user to /onboarding if not onboarded', () {
      authNotifier.setState(const AuthState(isAuthenticated: true, isOnboarded: false));
      final state = _createFakeState(matchedLocation: RoutePaths.ventas);

      final redirect = onboardingGuard.redirect(context, state);
      expect(redirect, equals(RoutePaths.onboarding));
    });

    test('permits access to /onboarding when authenticated and not onboarded', () {
      authNotifier.setState(const AuthState(isAuthenticated: true, isOnboarded: false));
      final state = _createFakeState(matchedLocation: RoutePaths.onboarding);

      final redirect = onboardingGuard.redirect(context, state);
      expect(redirect, isNull);
    });

    test('redirects from /onboarding to /ventas when already onboarded', () {
      authNotifier.setState(const AuthState(isAuthenticated: true, isOnboarded: true));
      final state = _createFakeState(matchedLocation: RoutePaths.onboarding);

      final redirect = onboardingGuard.redirect(context, state);
      expect(redirect, equals(RoutePaths.ventas));
    });

    test('permits access to regular routes when authenticated and onboarded', () {
      authNotifier.setState(const AuthState(isAuthenticated: true, isOnboarded: true));
      final state = _createFakeState(matchedLocation: RoutePaths.ventas);

      final redirect = onboardingGuard.redirect(context, state);
      expect(redirect, isNull);
    });
  });
}
