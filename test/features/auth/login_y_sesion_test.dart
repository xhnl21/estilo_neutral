import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:estilo_neutral/features/auth/application/auth_cubit.dart';
import 'package:estilo_neutral/features/auth/application/control_acceso_sesion.dart';
import 'package:estilo_neutral/features/auth/domain/auth_state.dart';
import 'package:estilo_neutral/features/auth/presentation/cubit/login_cubit.dart';
import 'package:estilo_neutral/features/auth/presentation/cubit/login_state.dart';
import 'package:estilo_neutral/features/notificaciones/infrastructure/push_gateway.dart';
import 'package:estilo_neutral/shared/auth/biometric_auth_service.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_auth.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../../test_servidor.dart';

const _org = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

class _Cuenta extends Fake implements GoogleSignInAccount {
  @override
  final String email;
  _Cuenta(this.email);
}

class _FakeSheetsAuth extends Fake implements SheetsAuth {
  GoogleSignInAccount? silenciosa;
  GoogleSignInAccount? interactiva;
  int signOuts = 0;

  @override
  Future<GoogleSignInAccount?> signInSilently() async => silenciosa;
  @override
  Future<GoogleSignInAccount?> signIn() async => interactiva;
  @override
  Future<void> signOut() async => signOuts++;
}

/// Solo el aviso de sesión revocada que deja el manejador de segundo plano.
class _PushConAviso extends PushNoDisponible {
  bool aviso = false;
  _PushConAviso() : super('test');
  @override
  Future<bool> consumirAvisoRevocacion() async {
    final hay = aviso;
    aviso = false;
    return hay;
  }
}

class _FakeBiometria extends Fake implements BiometricAuthService {
  bool resultado = true;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> hasFaceId() async => false;
  @override
  Future<bool> authenticate({String reason = ''}) async => resultado;
}

/// Datos de respaldo (Neida con biometría activa y Xavier sin método, ambos
/// en la organización por defecto) y un servidor simulado que confirma las
/// escrituras. Sin sesión ni organización actuales: las fija cada test.
late ServidorSimulado _servidor;

Future<SheetsDataService> _servicio() async {
  final (ds, servidor) = await servicioConServidor(usuario: null);
  _servidor = servidor;
  ds.setCurrentOrganizacion(null);
  return ds;
}

void main() {
  // ControlAccesoSesion observa el ciclo de vida de la app (WidgetsBinding).
  TestWidgetsFlutterBinding.ensureInitialized();
  late SheetsDataService ds;
  late AuthCubit auth;
  late _FakeSheetsAuth google;
  late _FakeBiometria biometria;

  setUp(() async {
    ds = await _servicio();
    auth = AuthCubit(initialState: const AuthState(isAuthenticated: false));
    google = _FakeSheetsAuth();
    biometria = _FakeBiometria();
  });

  LoginCubit loginCubit() => LoginCubit(
        authCubit: auth,
        sheetsAuth: google,
        dataService: ds,
        biometricAuthService: biometria,
      );

  group('LoginCubit', () {
    test('sin sesión previa muestra el botón', () async {
      final cubit = loginCubit();
      await cubit.restaurarSesion();
      expect(cubit.state.status, LoginStatus.listo);
      expect(cubit.state.showButton, isTrue);
      await cubit.close();
    });

    test('usuario autorizado sin método de seguridad entra directo', () async {
      google.silenciosa = _Cuenta('xhnl21@gmail.com');
      final cubit = loginCubit();
      await cubit.restaurarSesion();
      expect(cubit.state.status, LoginStatus.autenticado);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.organizacionId, _org);
      await cubit.close();
    });

    test('cuenta sin acceso: se rechaza y se cierra la sesión de Google', () async {
      google.interactiva = _Cuenta('intruso@gmail.com');
      final cubit = loginCubit();
      await cubit.restaurarSesion();
      await cubit.accionPrincipal();
      expect(cubit.state.status, LoginStatus.listo);
      expect(cubit.state.errorMessage, contains('no está registrada'));
      expect(google.signOuts, 1);
      expect(auth.isAuthenticated, isFalse);
      await cubit.close();
    });

    test('con biometría activa pide confirmarla antes de entrar', () async {
      google.silenciosa = _Cuenta('neidapulgar1989@gmail.com');
      final cubit = loginCubit();
      await cubit.restaurarSesion();
      expect(cubit.state.metodoPendiente, 'biometrico');
      expect(auth.isAuthenticated, isFalse);

      biometria.resultado = false;
      await cubit.accionPrincipal();
      expect(cubit.state.errorMessage, contains('No se pudo verificar'));

      biometria.resultado = true;
      await cubit.accionPrincipal();
      expect(cubit.state.status, LoginStatus.autenticado);
      expect(auth.isAuthenticated, isTrue);
      await cubit.close();
    });

    test('cuenta inactiva: no puede iniciar sesión', () async {
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      await ds.cambiarEstadoUsuario(usuario.id, activo: false);
      google.interactiva = _Cuenta('xhnl21@gmail.com');
      final cubit = loginCubit();
      await cubit.restaurarSesion();
      await cubit.accionPrincipal();
      expect(cubit.state.errorMessage, contains('está inactiva'));
      expect(auth.isAuthenticated, isFalse);
      expect(google.signOuts, 1);

      // Reactivada, vuelve a entrar.
      await ds.cambiarEstadoUsuario(usuario.id, activo: true);
      await cubit.accionPrincipal();
      expect(auth.isAuthenticated, isTrue);
      await cubit.close();
    });

    test('muestra el motivo de un cierre de sesión forzado', () async {
      auth.logout(motivo: 'Tu acceso fue revocado.');
      final cubit = loginCubit();
      expect(cubit.state.errorMessage, 'Tu acceso fue revocado.');
      await cubit.close();
    });
  });

  group('ControlAccesoSesion', () {
    late ControlAccesoSesion control;
    late _PushConAviso push;

    setUp(() {
      push = _PushConAviso();
      control = ControlAccesoSesion(dataService: ds, authCubit: auth, sheetsAuth: google, push: push);
      auth.login(email: 'xhnl21@gmail.com', organizacionId: _org);
      ds.setCurrentOrganizacion(_org);
      ds.setCurrentUsuario('xhnl21@gmail.com');
    });
    tearDown(() => control.dispose());

    test('un cambio que no afecta el acceso no cierra la sesión', () async {
      ds.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(auth.isAuthenticated, isTrue);
    });

    test('si eliminan al usuario con la app abierta, se cierra su sesión', () async {
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      await ds.deleteUsuario(usuario);
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isFalse);
      expect(auth.state.motivoCierreSesion, contains('revocado'));
      expect(google.signOuts, 1);
      expect(ds.currentOrganizacionId, isNull);
    });

    test('si lo inactivan (desde otro dispositivo), se cierra su sesión', () async {
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      ds.setCurrentUsuario('neidapulgar1989@gmail.com'); // lo inactiva otra cuenta
      await ds.cambiarEstadoUsuario(usuario.id, activo: false);
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isFalse);
      expect(auth.state.motivoCierreSesion, contains('está inactiva'));
      expect(google.signOuts, 1);
    });

    test('un aviso de sesión revocada (push en segundo plano) relee aunque no pasaron 30 s', () async {
      final t0 = DateTime(2026, 10, 7, 10);
      await control.alVolverAPrimerPlano(ahora: t0);
      _servidor.lecturas.clear();

      await control.alVolverAPrimerPlano(ahora: t0.add(const Duration(seconds: 5)));
      expect(_servidor.lecturas, isEmpty);

      push.aviso = true;
      await control.alVolverAPrimerPlano(ahora: t0.add(const Duration(seconds: 6)));
      expect(_servidor.lecturas['usuarios'], 1);
      expect(push.aviso, isFalse, reason: 'el aviso se consume');
    });

    test('si lo mueven de organización, tiene que volver a iniciar sesión', () async {
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      await ds.addOrganizacion('Otra');
      final otra = ds.organizaciones.firstWhere((o) => o.nombre == 'Otra');
      await ds.updateUsuario(usuario, organizacionId: otra.id);
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isFalse);
      expect(auth.state.motivoCierreSesion, contains('organización cambió'));
    });

    test('cada escritura lleva el email de la sesión', () async {
      await ds.addOrganizacion('Para probar');
      expect(_servidor.enviados.last['usuario_sesion'], 'xhnl21@gmail.com');
    });

    test('si el servidor rechaza una escritura por acceso revocado, se cierra la sesión', () async {
      // Lo revocaron desde otro dispositivo: la copia local todavía lo
      // muestra autorizado, pero Apps Script rechaza lo que intente guardar.
      _servidor.respuesta =
          '{"status":"error","code":"acceso_revocado","message":"La cuenta xhnl21@gmail.com ya no está autorizada."}';
      await expectLater(ds.addOrganizacion('No se guarda'), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);

      expect(ds.organizaciones.any((o) => o.nombre == 'No se guarda'), isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.state.motivoCierreSesion, contains('ya no está autorizada'));
      expect(google.signOuts, 1);
    });

    test('un rechazo por otro motivo no cierra la sesión', () async {
      _servidor.rechazar('Registro no encontrado');
      await expectLater(ds.addOrganizacion('X'), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      expect(auth.isAuthenticated, isTrue);
    });

    test('al volver a primer plano relee solo las hojas de acceso, como mucho una vez cada 30 s', () async {
      final t0 = DateTime(2026, 10, 7, 10);
      _servidor.lecturas.clear(); // descarta la carga inicial
      await control.alVolverAPrimerPlano(ahora: t0);
      expect(_servidor.lecturas.keys, unorderedEquals(['usuarios', 'organizaciones', 'usuario_organizacion']));
      expect(_servidor.lecturas['usuarios'], 1);

      await control.alVolverAPrimerPlano(ahora: t0.add(const Duration(seconds: 10)));
      expect(_servidor.lecturas['usuarios'], 1);

      await control.alVolverAPrimerPlano(ahora: t0.add(const Duration(seconds: 31)));
      expect(_servidor.lecturas['usuarios'], 2);
    });

    test('sin sesión abierta no relee al volver a primer plano', () async {
      auth.logout();
      _servidor.lecturas.clear();
      await control.alVolverAPrimerPlano();
      expect(_servidor.lecturas, isEmpty);
    });

    test('sin sesión abierta no hace nada', () async {
      auth.logout();
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      await ds.deleteUsuario(usuario);
      await Future<void>.delayed(Duration.zero);
      expect(google.signOuts, 0);
    });
  });
}
