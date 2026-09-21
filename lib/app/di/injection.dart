import '../../core/core.dart';
import '../../core/router/router.dart';
import '../../features/auth/auth.dart';
import '../../features/sales/infrastructure/infrastructure.dart';
import '../../features/sales/sales.dart';
import '../../shared/shared.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final EventBus eventBus;
  late final SecureTokenStorage tokenStorage;
  late final SheetsAuth sheetsAuth;
  late final SheetsClient sheetsClient;
  late final SheetsDataService sheetsDataService;

  late final SalesSheetsDataSource salesDataSource;
  late final CustomerRepository customerRepository;
  late final ProductRepository productRepository;
  late final SaleRepository saleRepository;

  late final CreateSaleUseCase createSaleUseCase;
  late final RegisterPaymentUseCase registerPaymentUseCase;
  late final RefreshSalesDataUseCase refreshSalesDataUseCase;
  late final SalesController salesController;

  late final AuthNotifier authNotifier;
  late final AppRouter appRouter;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  void init() {
    if (_initialized) return;
    _initialized = true;
    eventBus = EventBus();
    tokenStorage = SecureTokenStorage();
    sheetsAuth = SheetsAuth(tokenStorage: tokenStorage);
    sheetsClient = SheetsClient(
      tokenStorage: tokenStorage,
      spreadsheetId: SheetsConfig.defaultSpreadsheetId,
    );
    sheetsDataService = SheetsDataService(
      spreadsheetId: SheetsConfig.defaultSpreadsheetId,
    )..initialize();

    // Inicializar DataSource con datos reales normalizados de la hoja
    salesDataSource = InMemorySalesSheetsDataSource(
      initialCustomers: [
        const CustomerModel(
          id: 'c00000001',
          nombre: 'Neida',
          telefono: '+584120000001',
          email: 'neida.cliente@ejemplo.com',
          saldoDeudaUsd: 0.0,
          fechaRegistro: '2026-04-03',
        ),
      ],
      initialProducts: [
        const ProductModel(
          id: 'p00000001',
          cantidad: 10,
          nombre: 'Pantalon',
          marca: 'Generica',
          modelo: 'Casual',
          talla: 'M',
          precioUsd: 20.0,
          fotoUrl: 'https://lh3.googleusercontent.com/d/1_DRIVE_FILE_ID_PANTALON_CASUAL',
          fotoFormula: '=IF(H2="","",IMAGE(H2))',
        ),
      ],
      initialSales: [
        const SaleModel(
          id: 'v00000001',
          fecha: '2026-04-03',
          clienteId: 'c00000001',
          itemId: 'p00000001',
          cantidad: 1,
          tasaBcv: 474.0,
          tasaUsd: 30.0,
          tipoPago: 'Efectivo',
          comisionPagoMovilBs: 0.0,
          montoBs: 9480.0,
          montoUsd: 20.0,
          abonoUsd: 20.0,
          deudaUsd: 0.0,
          totalPagarUsd: 20.0,
          validacion: 'OK',
          estado: 'Pendiente',
        ),
      ],
    );

    customerRepository = CustomerRepositoryImpl(dataSource: salesDataSource);
    productRepository = ProductRepositoryImpl(dataSource: salesDataSource);
    saleRepository = SaleRepositoryImpl(dataSource: salesDataSource);

    createSaleUseCase = CreateSaleUseCase(
      saleRepository: saleRepository,
      productRepository: productRepository,
      customerRepository: customerRepository,
      eventBus: eventBus,
    );

    registerPaymentUseCase = RegisterPaymentUseCase(
      saleRepository: saleRepository,
      customerRepository: customerRepository,
      eventBus: eventBus,
    );

    refreshSalesDataUseCase = RefreshSalesDataUseCase(
      saleRepository: saleRepository,
      customerRepository: customerRepository,
      productRepository: productRepository,
    );

    salesController = SalesController(
      createSaleUseCase: createSaleUseCase,
      registerPaymentUseCase: registerPaymentUseCase,
      refreshSalesDataUseCase: refreshSalesDataUseCase,
      saleRepository: saleRepository,
    );

    authNotifier = AuthNotifier(
      initialState: const AuthState(isAuthenticated: false),
    );
    appRouter = AppRouter(
      authNotifier: authNotifier,
      salesController: salesController,
      dataService: sheetsDataService,
      sheetsAuth: sheetsAuth,
    );
  }
}

