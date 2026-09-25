import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/metodos_pago/metodos_pago_cubit.dart';
import '../cubits/metodos_pago/metodos_pago_state.dart';

/// Vista de Métodos de Pago (hoja: "metodo pago")
/// Administra los métodos de pago disponibles en el sistema y su estado activo/inactivo.
class MetodosPagoPage extends StatelessWidget {
  final SheetsDataService dataService;

  const MetodosPagoPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MetodosPagoCubit(dataService: dataService),
      child: _MetodosPagoView(dataService: dataService),
    );
  }
}

class _MetodosPagoView extends StatefulWidget {
  final SheetsDataService dataService;

  const _MetodosPagoView({required this.dataService});

  @override
  State<_MetodosPagoView> createState() => _MetodosPagoViewState();
}

class _MetodosPagoViewState extends State<_MetodosPagoView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MetodosPagoCubit, MetodosPagoState>(
      listenWhen: (prev, curr) =>
          curr.actionSuccessMessage != null &&
          prev.actionSuccessMessage != curr.actionSuccessMessage,
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppPalette.success,
              content: Text(state.actionSuccessMessage!),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<MetodosPagoCubit>();
        final metodos = state.filteredMetodos;
        final totalActivos = state.totalActivos;

        return AppScaffold(
          title: 'Métodos de Pago',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'metodo pago',
            userFriendlyText:
                '$totalActivos activos de ${state.metodos.length}',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == MetodosPagoStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_metodos_pago',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.creditcard_fill, size: 20),
            label: const Text('Nuevo Método',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: _showCrearMetodoDialog,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: AppTextField(
                  label: 'Buscar método de pago',
                  hint: 'Nombre o código...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => cubit.search(val),
                ),
              ),
              Expanded(
                child: metodos.isEmpty
                    ? const AppEmptyState(
                        title: 'No se encontraron métodos de pago',
                        description:
                            'Usa el botón "Nuevo Método" para registrar uno.',
                        icon: CupertinoIcons.creditcard,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: metodos.length,
                        itemBuilder: (context, index) {
                          final metodo = metodos[index];
                          final enUso =
                              widget.dataService.isMetodoPagoEnUso(metodo.id);

                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ExcludeSemantics(
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: metodo.status
                                          ? AppPalette.blue100
                                          : AppPalette.divider,
                                      child: Icon(
                                        CupertinoIcons.creditcard,
                                        color: metodo.status
                                            ? AppPalette.blue700
                                            : AppPalette.textDisabled,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                metodo.nombre,
                                                style: AppTypography.titleLarge
                                                    .copyWith(
                                                  fontSize: 15,
                                                  color: metodo.status
                                                      ? AppPalette.textPrimary
                                                      : AppPalette.textDisabled,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: ${metodo.id}',
                                          style:
                                              AppTypography.labelSmall.copyWith(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppPalette.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            AppChip(
                                              label: metodo.status
                                                  ? 'Activo'
                                                  : 'Inactivo',
                                              variant: metodo.status
                                                  ? AppChipVariant.success
                                                  : AppChipVariant.info,
                                            ),
                                            if (enUso)
                                              const AppChip(
                                                label: 'En uso',
                                                variant: AppChipVariant.warning,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Semantics(
                                    label:
                                        'Alternar estado de ${metodo.nombre}',
                                    child: Switch.adaptive(
                                      value: metodo.status,
                                      activeTrackColor: AppPalette.primary,
                                      onChanged: (val) => _handleToggleStatus(
                                          metodo, enUso),
                                    ),
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

  Future<void> _handleToggleStatus(MetodoPago metodo, bool enUso) async {
    // Si está activo y se intenta deshabilitar pero está en uso: BLOQUEAR
    if (metodo.status && enUso) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(CupertinoIcons.exclamationmark_shield_fill,
              color: AppPalette.warning, size: 36),
          title: const Text('No se puede deshabilitar'),
          content: Text(
            'El método de pago "${metodo.nombre}" (ID: ${metodo.id}) está actualmente siendo utilizado en ventas o abonos registrados.\n\nPor integridad contable y normativa ISO 8000, los métodos en uso no pueden desactivarse.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await widget.dataService.toggleMetodoPagoStatus(metodo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            metodo.status
                ? 'Método "${metodo.nombre}" deshabilitado.'
                : 'Método "${metodo.nombre}" habilitado correctamente.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppPalette.error,
        ),
      );
    }
  }

  Future<void> _showCrearMetodoDialog() async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Método de Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el nombre del método de pago que estará disponible en ventas y abonos.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre del método',
                  hintText: 'Ej: Zelle Empresa, Tarjeta Débito...',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = controller.text.trim();
                if (nombre.isEmpty) {
                  setDialogState(
                      () => errorText = 'El nombre no puede estar vacío');
                  return;
                }

                if (widget.dataService.metodosPago.any(
                    (m) => m.nombre.toLowerCase() == nombre.toLowerCase())) {
                  setDialogState(
                      () => errorText = 'Ya existe un método con ese nombre');
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  await widget.dataService.addMetodoPago(nombre: nombre);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Método "$nombre" creado exitosamente')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppPalette.error),
                  );
                }
              },
              child: const Text('Crear Método'),
            ),
          ],
        ),
      ),
    );
  }
}
