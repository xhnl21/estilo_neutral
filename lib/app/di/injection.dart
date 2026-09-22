import '../../core/router/router.dart';
import '../../features/auth/auth.dart';
import '../../shared/shared.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final SecureTokenStorage tokenStorage;
  late final SheetsAuth sheetsAuth;
  late final SheetsClient sheetsClient;
  late final SheetsDataService sheetsDataService;

  late final AuthNotifier authNotifier;
  late final AppRouter appRouter;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  void init() {
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
    )..initialize();

    authNotifier = AuthNotifier(
      initialState: const AuthState(isAuthenticated: false),
    );
    appRouter = AppRouter(
      authNotifier: authNotifier,
      dataService: sheetsDataService,
      sheetsAuth: sheetsAuth,
    );
  }
}
