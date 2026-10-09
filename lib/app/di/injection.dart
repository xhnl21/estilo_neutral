import 'package:dio/dio.dart';
import '../../core/router/router.dart';
import '../../features/auth/auth.dart';
import '../../features/credits/credits.dart';
import '../../features/notificaciones/infrastructure/push_gateway.dart';
import '../../features/notificaciones/presentation/cubit/push_cubit.dart';
import '../../shared/shared.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final SecureTokenStorage tokenStorage;
  late final SheetsAuth sheetsAuth;
  late final SheetsClient sheetsClient;
  late final SheetsDataService sheetsDataService;
  SheetsCreditsDataSource? _creditsDataSource;
  ClientCreditRepository? _creditRepository;

  SheetsCreditsDataSource get creditsDataSource {
    if (_creditsDataSource != null) return _creditsDataSource!;
    if (_initialized) {
      return _creditsDataSource ??= SheetsCreditsDataSource(dataService: sheetsDataService);
    }
    return _creditsDataSource ??= SheetsCreditsDataSource(
      dataService: SheetsDataService(spreadsheetId: SheetsConfig.defaultSpreadsheetId),
    );
  }

  set creditsDataSource(SheetsCreditsDataSource value) {
    _creditsDataSource = value;
  }

  ClientCreditRepository get creditRepository {
    if (_creditRepository != null) return _creditRepository!;
    return _creditRepository ??= ClientCreditRepositoryImpl(dataSource: creditsDataSource);
  }

  set creditRepository(ClientCreditRepository value) {
    _creditRepository = value;
  }

  late final AuthCubit authCubit;
  late final ControlAccesoSesion controlAccesoSesion;
  late final AppRouter appRouter;

  /// Notificaciones push (FCM). Con [PushNoDisponible] queda inactivo.
  late final PushCubit pushCubit;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// [dio] es un punto de inyección solo para tests: permite reemplazar el
  /// cliente HTTP real por uno falso (ver `_FakeHttpClientAdapter` en los
  /// tests de widgets) para no depender de la red real dentro de
  /// `testWidgets()` — ahí Flutter intercepta el `HttpClient` y una llamada
  /// real puede volverse lenta/errática en vez de fallar rápido.
  /// [push] es el canal de notificaciones ya inicializado (ver main.dart);
  /// sin él, la app funciona sin notificaciones.
  void init({Dio? dio, PushGateway push = const PushNoDisponible('Sin inicializar.')}) {
    if (_initialized) return;
    _initialized = true;
    tokenStorage = SecureTokenStorage();
    sheetsAuth = SheetsAuth(tokenStorage: tokenStorage);
    sheetsClient = SheetsClient(
      tokenStorage: tokenStorage,
      spreadsheetId: SheetsConfig.defaultSpreadsheetId,
    );
    sheetsDataService = SheetsDataService(
      spreadsheetId: SheetsConfig.defaultSpreadsheetId,
      dio: dio,
      // Nunca datos de ejemplo en la app: si no se puede leer, se avisa.
      datosDeRespaldo: false,
    )
      // Cada pedido al Apps Script lleva el token de Google de la sesión.
      ..proveedorToken = sheetsAuth.tokenDeAcceso
      ..renovadorToken = sheetsAuth.renovarTokenDeAcceso
      // Sin sesión no se lee (la hoja es privada): la primera carga la hace
      // el login, con la sesión de Google ya restaurada.
      ..initialize(cargarSinSesion: false);

    _creditsDataSource = SheetsCreditsDataSource(dataService: sheetsDataService);
    _creditRepository = ClientCreditRepositoryImpl(dataSource: _creditsDataSource!);

    authCubit = AuthCubit(
      initialState: const AuthState(isAuthenticated: false),
    );
    controlAccesoSesion = ControlAccesoSesion(
      dataService: sheetsDataService,
      authCubit: authCubit,
      sheetsAuth: sheetsAuth,
      push: push,
    );
    appRouter = AppRouter(
      authCubit: authCubit,
      dataService: sheetsDataService,
      sheetsAuth: sheetsAuth,
    );
    pushCubit = PushCubit(
      gateway: push,
      dataService: sheetsDataService,
      authCubit: authCubit,
      navegar: (ruta) => appRouter.router.go(ruta),
    );
  }
}
