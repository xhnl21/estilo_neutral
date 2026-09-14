import 'package:flutter/material.dart';
import '../controllers/sales_controller.dart';
import '../widgets/sale_list_item.dart';

class SalesPage extends StatefulWidget {
  final SalesController controller;

  const SalesPage({super.key, required this.controller});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  @override
  void initState() {
    super.initState();
    // Carga inicial bajo demanda al abrir pantalla (UNA sola llamada puntual, cero polling)
    widget.controller.loadSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estilo Neutral — Ventas'),
        elevation: 0,
        actions: [
          // Botón obligatorio: "Actualizar" manual bajo demanda (Fase 11.11.6)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar (Bajo demanda)',
            onPressed: () => widget.controller.onRefreshButtonPressed(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;

          if (state is SalesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SalesError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      state.userFriendlyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => widget.controller.onRefreshButtonPressed(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is SalesSuccess) {
            if (state.sales.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No hay ventas registradas.'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => widget.controller.onRefreshButtonPressed(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              // Pull-to-refresh manual bajo demanda del usuario
              onRefresh: () => widget.controller.onRefreshButtonPressed(),
              child: ListView.builder(
                itemCount: state.sales.length,
                itemBuilder: (context, index) {
                  final sale = state.sales[index];
                  return SaleListItem(sale: sale);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
