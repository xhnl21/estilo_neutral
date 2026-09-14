import 'package:flutter/material.dart';
import '../../application/dtos/sale_dto.dart';

class SaleListItem extends StatelessWidget {
  final SaleDto sale;
  final VoidCallback? onTap;

  const SaleListItem({
    super.key,
    required this.sale,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = sale.estado.toLowerCase() == 'pagada';
    final hasDebt = sale.deudaUsd > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isPaid ? Colors.green.shade100 : Colors.amber.shade100,
          child: Icon(
            isPaid ? Icons.check_circle_outline : Icons.pending_outlined,
            color: isPaid ? Colors.green.shade800 : Colors.amber.shade900,
          ),
        ),
        title: Text(
          'Venta ${sale.id} • ${sale.date}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Cliente: ${sale.customerId} | Pago: ${sale.paymentMethod}'),
            if (hasDebt)
              Text(
                'Deuda: \$${sale.deudaUsd.toStringAsFixed(2)} USD',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${sale.totalPagarUsd.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${sale.montoBs.toStringAsFixed(2)} Bs',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
