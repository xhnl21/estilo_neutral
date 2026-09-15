import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/icons.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/tokens/typography.dart';
import '../../core/design_system/widgets/app_button.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../../core/design_system/widgets/app_empty_state.dart';
import '../../core/design_system/widgets/app_money_text.dart';
import '../../core/design_system/widgets/app_outlined_button.dart';
import '../../core/design_system/widgets/app_refresh_button.dart';
import '../../core/design_system/widgets/app_scaffold.dart';
import '../../core/design_system/widgets/app_text_field.dart';
import '../../models/cliente.dart';
import '../../shared/google_sheets/apps_script_source.dart';
import '../../shared/google_sheets/sheets_data_service.dart';

/// Vista de Clientes (hoja: clientes)
/// Operaciones CRUD completas y Cero Polling.
class ClientesPage extends StatefulWidget {
  final SheetsDataService dataService;

  const ClientesPage({super.key, required this.dataService});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final clientes = widget.dataService.clientes.where((c) {
          final q = _searchQuery.toLowerCase();
          return c.nombre.toLowerCase().contains(q) ||
              c.telefono.toLowerCase().contains(q) ||
              c.id.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q);
        }).toList();

        return AppScaffold(
          title: 'Clientes',
          subtitle: 'Hoja clientes • ${widget.dataService.clientes.length} registros',
          actions: [
            IconButton(
              icon: Icon(
                widget.dataService.appsScriptUrl != null && widget.dataService.appsScriptUrl!.isNotEmpty
                    ? CupertinoIcons.cloud_upload_fill
                    : CupertinoIcons.cloud_upload,
                color: widget.dataService.appsScriptUrl != null && widget.dataService.appsScriptUrl!.isNotEmpty
                    ? AppPalette.success
                    : AppPalette.warning,
                size: 20,
              ),
              tooltip: 'Vincular Google Sheets (Escritura)',
              onPressed: () => _showAppsScriptConfigDialog(context),
            ),
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.person_badge_plus, size: 20),
            label: const Text('Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showClienteDialog(context),
          ),
          body: Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: AppTextField(
                  label: 'Buscar cliente',
                  hint: 'Nombre, teléfono (+58...) o ID...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              if (widget.dataService.appsScriptUrl == null || widget.dataService.appsScriptUrl!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: InkWell(
                    onTap: () => _showAppsScriptConfigDialog(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: AppCard(
                      padding: AppSpacing.pSm,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.info_circle_fill, size: 16, color: AppPalette.blue700),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Escritura en la nube pendiente. Toca aquí para vincular tu Google Apps Script.',
                              style: AppTypography.labelSmall.copyWith(color: AppPalette.blue700, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_right, size: 14, color: AppPalette.blue700),
                        ],
                      ),
                    ),
                  ),
                ),

              if (widget.dataService.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: AppCard(
                    padding: AppSpacing.pSm,
                    child: Row(
                      children: [
                        const Icon(AppIcons.warning, size: 16, color: AppPalette.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.dataService.errorMessage!,
                            style: AppTypography.labelSmall.copyWith(color: AppPalette.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Lista de clientes
              Expanded(
                child: clientes.isEmpty
                    ? const AppEmptyState(
                        title: 'No hay clientes registrados',
                        description: 'Usa el botón "Nuevo Cliente" para registrar uno.',
                        icon: CupertinoIcons.person_2,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: clientes.length,
                        itemBuilder: (context, index) {
                          final cliente = clientes[index];
                          final hasDebt = cliente.saldoDeudaUsd > 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: hasDebt ? const Color(0xFFFFEBEE) : AppPalette.blue100,
                                    child: Icon(
                                      CupertinoIcons.person_fill,
                                      color: hasDebt ? AppPalette.error : AppPalette.blue700,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            text: cliente.nombre,
                                            style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                            children: [
                                              TextSpan(
                                                text: ' (${cliente.id})',
                                                style: AppTypography.labelSmall.copyWith(
                                                  color: AppPalette.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '📞 ${cliente.telefono} • ✉️ ${cliente.email}',
                                          style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: [
                                            Text(
                                              'Deuda: ',
                                              style: AppTypography.labelSmall.copyWith(
                                                color: hasDebt ? AppPalette.error : AppPalette.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            AppMoneyText(
                                              amount: cliente.saldoDeudaUsd,
                                              currency: MoneyCurrency.usd,
                                              nature: hasDebt ? MoneyNature.debt : MoneyNature.neutral,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            Text(
                                              '• Reg: ${cliente.fechaRegistro.toIso8601String().split('T').first}',
                                              style: AppTypography.labelSmall.copyWith(
                                                fontSize: 11,
                                                color: AppPalette.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Botones de acción CRUD
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                        tooltip: 'Editar Cliente',
                                        onPressed: () => _showClienteDialog(context, cliente: cliente),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                        tooltip: 'Eliminar Cliente',
                                        onPressed: () => _confirmDelete(context, cliente),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClienteDialog(BuildContext context, {Cliente? cliente}) {
    final isEditing = cliente != null;
    final id = isEditing ? cliente.id : widget.dataService.nextClienteId;
    final nombreController = TextEditingController(text: cliente?.nombre ?? '');
    final telefonoController = TextEditingController(text: cliente?.telefono ?? '+58');
    final emailController = TextEditingController(text: cliente?.email ?? '');
    final deudaController = TextEditingController(text: cliente?.saldoDeudaUsd.toStringAsFixed(2) ?? '0.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Editar Cliente ($id)' : 'Registrar Nuevo Cliente',
                    style: AppTypography.titleLarge.copyWith(fontSize: 17),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Nombre Completo',
                controller: nombreController,
                hint: 'Ej: Neida Gómez',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Teléfono (E.164)',
                controller: telefonoController,
                hint: '+584120000001',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Correo Electrónico',
                controller: emailController,
                hint: 'cliente@ejemplo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Saldo Deuda Inicial (USD)',
                controller: deudaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(
                      label: 'Cancelar',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: isEditing ? 'Guardar Cambios' : 'Registrar',
                      icon: isEditing ? CupertinoIcons.check_mark : CupertinoIcons.add,
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        if (nombre.isEmpty) return;

                        final nuevoCliente = Cliente(
                          id: id,
                          nombre: nombre,
                          telefono: telefonoController.text.trim(),
                          email: emailController.text.trim(),
                          saldoDeudaUsd: double.tryParse(deudaController.text.replaceAll(',', '.')) ?? 0.0,
                          fechaRegistro: cliente?.fechaRegistro ?? DateTime.now(),
                        );

                        Navigator.pop(ctx);

                        if (isEditing) {
                          widget.dataService.updateCliente(nuevoCliente);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cliente ${nuevoCliente.nombre} actualizado.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          final cloudSynced = await widget.dataService.addCliente(nuevoCliente);
                          if (!context.mounted) return;
                          if (cloudSynced) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppPalette.success,
                                content: Text('✅ Cliente ${nuevoCliente.nombre} guardado y sincronizado con Google Sheets.'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else if (widget.dataService.appsScriptUrl == null || widget.dataService.appsScriptUrl!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppPalette.blue700,
                                content: Text('💾 Cliente ${nuevoCliente.nombre} guardado en el dispositivo. Vincula Apps Script para guardar en Google Sheets.'),
                                action: SnackBarAction(
                                  label: 'Vincular',
                                  textColor: Colors.white,
                                  onPressed: () => _showAppsScriptConfigDialog(context),
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppPalette.warning,
                                content: Text('💾 Guardado localmente. Error de conexión con Google Apps Script.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppsScriptConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.dataService.appsScriptUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(CupertinoIcons.cloud_upload_fill, color: AppPalette.primary),
            SizedBox(width: 8),
            Text('Vincular Google Sheets', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para que los nuevos clientes se guarden en tu Google Sheet en tiempo real, ingresa la URL de tu Web App de Google Apps Script:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'URL de Apps Script (exec)',
              controller: controller,
              hint: 'https://script.google.com/macros/s/.../exec',
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
              label: const Text('Copiar código Apps Script al portapapeles', style: TextStyle(fontSize: 12)),
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: googleAppsScriptSourceCode));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Código de Apps Script copiado al portapapeles.')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: const Text('Guardar'),
            onPressed: () async {
              final url = controller.text.trim();
              await widget.dataService.setAppsScriptUrl(url);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL de Apps Script guardada correctamente.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Cliente cliente) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cliente?'),
        content: Text('Se desincorporará a ${cliente.nombre} (${cliente.id}) de la base de datos.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              widget.dataService.deleteCliente(cliente.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
