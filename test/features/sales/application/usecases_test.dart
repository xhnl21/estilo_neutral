import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/events/event_bus.dart';
import 'package:estilo_neutral/features/sales/application/usecases/create_sale.dart';
import 'package:estilo_neutral/features/sales/application/usecases/register_payment.dart';
import 'package:estilo_neutral/features/sales/infrastructure/datasources/sales_sheets_datasource.dart';
import 'package:estilo_neutral/features/sales/infrastructure/repositories/customer_repository_impl.dart';
import 'package:estilo_neutral/features/sales/infrastructure/repositories/product_repository_impl.dart';
import 'package:estilo_neutral/features/sales/infrastructure/repositories/sale_repository_impl.dart';
import 'package:estilo_neutral/features/sales/infrastructure/models/customer_model.dart';
import 'package:estilo_neutral/features/sales/infrastructure/models/product_model.dart';

void main() {
  group('Use Cases Tests (Application Layer)', () {
    late InMemorySalesSheetsDataSource dataSource;
    late CustomerRepositoryImpl customerRepo;
    late ProductRepositoryImpl productRepo;
    late SaleRepositoryImpl saleRepo;
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
      dataSource = InMemorySalesSheetsDataSource(
        initialCustomers: [
          const CustomerModel(
            id: 'c00000001',
            nombre: 'Neida',
            telefono: '+584120000001',
            email: 'neida@mail.com',
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
          ),
        ],
        initialSales: [],
      );

      customerRepo = CustomerRepositoryImpl(dataSource: dataSource);
      productRepo = ProductRepositoryImpl(dataSource: dataSource);
      saleRepo = SaleRepositoryImpl(dataSource: dataSource);
    });

    test('CreateSaleUseCase orquesta venta, decrementa stock y actualiza deuda', () async {
      final useCase = CreateSaleUseCase(
        saleRepository: saleRepo,
        productRepository: productRepo,
        customerRepository: customerRepo,
        eventBus: eventBus,
      );

      const params = CreateSaleParams(
        saleId: 'v00000001',
        customerId: 'c00000001',
        productId: 'p00000001',
        quantity: 2,
        bcvRate: 474.0,
        usdRate: 800.0,
        paymentMethod: 'Efectivo',
        mobilePaymentFeeBs: 0.0,
        paidAmount: 20.0, // Total es 40, deja deuda de 20
      );

      final result = await useCase(params);
      expect(result.isSuccess, isTrue);

      final dto = result.getOrNull!;
      expect(dto.id, 'v00000001');
      expect(dto.totalPagarUsd, 40.0);
      expect(dto.deudaUsd, 20.0);
      expect(dto.montoBs, 18960.0);

      // Verificar que el stock disminuyó en 2
      final updatedProduct = await productRepo.findAll();
      expect(updatedProduct.getOrNull!.first.stock.value, 8);

      // Verificar que la deuda del cliente aumentó en 20
      final updatedCustomer = await customerRepo.findAll();
      expect(updatedCustomer.getOrNull!.first.debtBalance.value, 20.0);
    });

    test('RegisterPaymentUseCase reduce deuda y cierra la venta', () async {
      final createUseCase = CreateSaleUseCase(
        saleRepository: saleRepo,
        productRepository: productRepo,
        customerRepository: customerRepo,
        eventBus: eventBus,
      );

      await createUseCase(const CreateSaleParams(
        saleId: 'v00000001',
        customerId: 'c00000001',
        productId: 'p00000001',
        quantity: 1,
        bcvRate: 474.0,
        usdRate: 800.0,
        paymentMethod: 'Efectivo',
        mobilePaymentFeeBs: 0.0,
        paidAmount: 10.0, // Deuda restante: 10.0
      ));

      final registerPaymentUseCase = RegisterPaymentUseCase(
        saleRepository: saleRepo,
        customerRepository: customerRepo,
        eventBus: eventBus,
      );

      final paymentResult = await registerPaymentUseCase(const RegisterPaymentParams(
        saleId: 'v00000001',
        paymentAmount: 10.0,
        paymentMethod: 'Efectivo',
      ));

      expect(paymentResult.isSuccess, isTrue);
      final dto = paymentResult.getOrNull!;
      expect(dto.deudaUsd, 0.0);
      expect(dto.estado, 'Pagada');
    });
  });
}
