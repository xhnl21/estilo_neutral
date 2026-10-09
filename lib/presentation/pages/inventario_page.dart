
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/foto_producto/foto_producto_cubit.dart';
import '../cubits/foto_producto/foto_producto_state.dart';
import '../cubits/inventario/inventario_cubit.dart';
import '../cubits/inventario/inventario_state.dart';

/// Vista de Inventario / Catálogo de Productos (hoja: inventario)
/// La foto de cada producto se toma con la cámara o se elige de la
/// galería del teléfono — el usuario nunca ve rutas ni IDs de Google
/// Drive (ver [_FotoPicker] y [SheetsDataService.subirFotoGaleria]).
class InventarioPage extends StatelessWidget {
  final SheetsDataService dataService;
  final String? initialSearchQuery;

  const InventarioPage({
    super.key,
    required this.dataService,
    this.initialSearchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InventarioCubit(
        dataService: dataService,
        initialSearchQuery: initialSearchQuery,
      ),
      child: _InventarioView(dataService: dataService),
    );
  }
}

class _InventarioView extends StatefulWidget {
  final SheetsDataService dataService;

  const _InventarioView({required this.dataService});

  @override
  State<_InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<_InventarioView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InventarioCubit, InventarioState>(
      listenWhen: (prev, curr) =>
          (curr.actionSuccessMessage != null &&
              prev.actionSuccessMessage != curr.actionSuccessMessage) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        final error = state.errorMessage;
        final exito = state.actionSuccessMessage;
        if (error == null && exito == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: error != null ? AppPalette.error : AppPalette.success,
            content: Text(error ?? exito!),
            duration: Duration(seconds: error != null ? 4 : 2),
          ),
        );
      },
      builder: (context, state) {
        final cubit = context.read<InventarioCubit>();
        final productos = state.filteredProductos;

        return AppScaffold(
          title: 'Inventario',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'inventario',
            userFriendlyText: '${state.productos.length} productos registrados',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == InventarioStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_inventario',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.plus_app, size: 20),
            label: const Text('Nuevo Producto',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showProductoDialog(context),
          ),
          body: Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: AppTextField(
                  label: 'Buscar producto',
                  hint: 'Prenda, marca, modelo, talla o ID...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => cubit.search(val),
                ),
              ),

              // Lista de productos con Skeleton progresivo
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: (state.status == InventarioStatus.loading &&
                          state.productos.isEmpty)
                      ? const InventarioSkeleton(
                          key: ValueKey('inventario_skeleton'),
                        )
                      : productos.isEmpty
                          ? const AppEmptyState(
                              key: ValueKey('inventario_empty'),
                              title: 'No hay productos en inventario',
                              description:
                                  'Registra prendas usando el botón "Nuevo Producto".',
                              icon: CupertinoIcons.tag,
                            )
                          : ListView(
                              key: const ValueKey('inventario_list'),
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg, 0, AppSpacing.lg, 80),
                              children: [
                                ExpansionPanelList(
                                  elevation: 1,
                                  expandedHeaderPadding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  expansionCallback: (panelIndex, isExpanded) {
                                    final producto = productos[panelIndex];
                                    cubit.toggleExpanded(producto.id);
                                  },
                                  children:
                                      productos.map<ExpansionPanel>((producto) {
                                    final isDepleted = producto.cantidad <= 0;
                                    final isLowStock = producto.cantidad > 0 &&
                                        producto.cantidad <= 3;
                                    final fotoUrl = widget.dataService
                                        .fotoUrlPorId(producto.fotoId);
                                    final hasPhoto =
                                        fotoUrl != null && fotoUrl.isNotEmpty;
                                    final isExpanded =
                                        state.expandedProductoId == producto.id;

                                    return ExpansionPanel(
                                      isExpanded: isExpanded,
                                      canTapOnHeader: true,
                                      backgroundColor: AppPalette.surface,
                                      headerBuilder:
                                          (context, isHeaderExpanded) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: AppSpacing.sm),
                                          child: Row(
                                            children: [
                                              // Miniatura foto
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: AppPalette.blue100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: hasPhoto
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.network(
                                                          fotoUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  const Center(
                                                            child: Icon(
                                                                CupertinoIcons
                                                                    .photo,
                                                                color: AppPalette
                                                                    .blue700,
                                                                size: 20),
                                                          ),
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: Icon(
                                                            CupertinoIcons
                                                                .tag_fill,
                                                            color: AppPalette
                                                                .blue700,
                                                            size: 20),
                                                      ),
                                              ),
                                              const SizedBox(
                                                  width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      producto.nombre,
                                                      style: AppTypography
                                                          .titleLarge
                                                          .copyWith(
                                                              fontSize: 15),
                                                      maxLines: isHeaderExpanded
                                                          ? null
                                                          : 1,
                                                      overflow: isHeaderExpanded
                                                          ? null
                                                          : TextOverflow
                                                              .ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 6,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          'ID: ${producto.id}',
                                                          style: AppTypography
                                                              .labelSmall
                                                              .copyWith(
                                                            color: AppPalette
                                                                .textSecondary,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        AppChip(
                                                          label: isDepleted
                                                              ? 'Agotado'
                                                              : (isLowStock
                                                                  ? 'Bajo stock (${producto.cantidad})'
                                                                  : 'Stock: ${producto.cantidad}'),
                                                          variant: isDepleted
                                                              ? AppChipVariant
                                                                  .error
                                                              : (isLowStock
                                                                  ? AppChipVariant
                                                                      .warning
                                                                  : AppChipVariant
                                                                      .success),
                                                        ),
                                                        AppMoneyText(
                                                          amount: producto
                                                              .precioUsd,
                                                          currency:
                                                              MoneyCurrency.usd,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      body: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.md,
                                            0,
                                            AppSpacing.md,
                                            AppSpacing.md),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Divider(
                                                color: AppPalette.divider),
                                            const SizedBox(height: 4),
                                            SelectableText.rich(
                                              TextSpan(
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                        fontSize: 13,
                                                        height: 1.5),
                                                children: [
                                                  const TextSpan(
                                                      text: '🏷️ Marca: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: producto
                                                              .marca.isNotEmpty
                                                          ? producto.marca
                                                          : 'Sin marca'),
                                                  const TextSpan(
                                                      text: '\n👗 Modelo: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: producto
                                                              .modelo.isNotEmpty
                                                          ? producto.modelo
                                                          : 'Sin modelo'),
                                                  const TextSpan(
                                                      text: '\n📏 Talla: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: producto
                                                              .talla.isNotEmpty
                                                          ? producto.talla
                                                          : 'Única'),
                                                  const TextSpan(
                                                      text:
                                                          '\n🏢 Organización: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: producto
                                                          .organizacionId),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              alignment:
                                                  WrapAlignment.spaceBetween,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: AppSpacing.sm,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Ajustar existencias: ',
                                                      style: AppTypography
                                                          .labelSmall
                                                          .copyWith(
                                                        color: AppPalette
                                                            .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    IconButton.filledTonal(
                                                      iconSize: 14,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                              minWidth: 28,
                                                              minHeight: 28),
                                                      icon: const Icon(
                                                          CupertinoIcons.minus),
                                                      tooltip: 'Reducir stock',
                                                      onPressed: isDepleted
                                                          ? null
                                                          : () => cubit.adjustStock(
                                                                  producto.id,
                                                                  -1),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8),
                                                      child: Text(
                                                        '${producto.cantidad}',
                                                        style: AppTypography
                                                            .titleLarge
                                                            .copyWith(
                                                                fontSize: 14),
                                                      ),
                                                    ),
                                                    IconButton.filledTonal(
                                                      iconSize: 14,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                              minWidth: 28,
                                                              minHeight: 28),
                                                      icon: const Icon(
                                                          CupertinoIcons.plus),
                                                      tooltip: 'Aumentar stock',
                                                      onPressed: () => cubit.adjustStock(
                                                              producto.id, 1),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 1,
                                              runSpacing: 1,
                                              children: [
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    foregroundColor:
                                                        AppPalette.blue700,
                                                    side: const BorderSide(
                                                        color:
                                                            AppPalette.border),
                                                  ),
                                                  icon: const Icon(
                                                      CupertinoIcons
                                                          .photo_camera,
                                                      size: 16),
                                                  label: const Text('Foto'),
                                                  onPressed: () =>
                                                      _showFotoActionSheet(
                                                          context, producto),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    foregroundColor:
                                                        AppPalette.blue700,
                                                    side: const BorderSide(
                                                        color:
                                                            AppPalette.border),
                                                  ),
                                                  icon: const Icon(
                                                      CupertinoIcons.pencil,
                                                      size: 16),
                                                  label: const Text('Editar'),
                                                  onPressed: () =>
                                                      _showProductoDialog(
                                                          context,
                                                          producto: producto),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    foregroundColor:
                                                        AppPalette.error,
                                                    side: const BorderSide(
                                                        color:
                                                            AppPalette.border),
                                                  ),
                                                  icon: const Icon(
                                                      CupertinoIcons.trash,
                                                      size: 16),
                                                  label: const Text('Eliminar'),
                                                  onPressed: () =>
                                                      _confirmDelete(
                                                          context, producto),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet para tomar/elegir/descargar la foto de un producto que ya
  /// existe en inventario — los cambios se guardan al instante (no hace
  /// falta un botón "Guardar" aparte, es la única acción de este diálogo).
  void _showFotoActionSheet(BuildContext context, Producto producto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Builder(
        builder: (context) => Padding(
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
                  Flexible(
                    child: Text(
                      'Foto de ${producto.nombre}',
                      style: AppTypography.titleLarge.copyWith(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill,
                        color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _FotoPicker(
                fotoId: producto.fotoId,
                dataService: widget.dataService,
                productoId: producto.id,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductoDialog(BuildContext context, {Producto? producto}) {
    // Los diálogos no quedan debajo del BlocProvider: se toma el Cubit acá.
    final cubit = context.read<InventarioCubit>();
    final isEditing = producto != null;
    final id = isEditing ? producto.id : widget.dataService.nextProductoId;
    final nombreController =
        TextEditingController(text: producto?.nombre ?? '');
    // Un producto nuevo no trae valores de ejemplo (stock y precio se
    // podían guardar por error; regla R7 de docs/estandar-hojas.md).
    final marcaController = TextEditingController(text: producto?.marca ?? '');
    final modeloController = TextEditingController(text: producto?.modelo ?? '');
    final tallaController = TextEditingController(text: producto?.talla ?? '');
    final cantidadController =
        TextEditingController(text: producto?.cantidad.toString() ?? '');
    final precioController = TextEditingController(
        text: producto?.precioUsd.toStringAsFixed(2) ?? '');
    var pendingFotoId = producto?.fotoId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEditing
                              ? 'Editar Producto ($id)'
                              : 'Registrar Nuevo Producto',
                          style: AppTypography.titleLarge.copyWith(fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill,
                            color: AppPalette.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FotoPicker(
                    fotoId: pendingFotoId,
                    dataService: widget.dataService,
                    onChanged: (nuevoFotoId) => pendingFotoId = nuevoFotoId,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Nombre de la Prenda',
                    controller: nombreController,
                    hint: 'Ej: Pantalón, Camisa, Zapato...',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Marca',
                          controller: marcaController,
                          hint: 'Ej: Levi\'s',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'Modelo',
                          controller: modeloController,
                          hint: 'Ej: Casual',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Talla',
                          controller: tallaController,
                          hint: 'S, M, L, XL, 32...',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'Cantidad en Stock',
                          controller: cantidadController,
                          hint: 'Ej: 10',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Precio Unitario (USD)',
                    controller: precioController,
                    hint: 'Ej: 20.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                          icon: isEditing
                              ? CupertinoIcons.check_mark
                              : CupertinoIcons.add,
                          onPressed: () {
                            final armado = InventarioCubit.construirProducto(
                              id: id,
                              nombre: nombreController.text,
                              marca: marcaController.text,
                              modelo: modeloController.text,
                              talla: tallaController.text,
                              cantidad: cantidadController.text,
                              precio: precioController.text,
                              fotoId: pendingFotoId,
                            );
                            final p = armado.producto;
                            if (p == null) {
                              showDialog(
                                context: ctx,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Revisá los datos'),
                                  content: Text(armado.error!),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx),
                                      child: const Text('Entendido'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            if (isEditing) {
                              cubit.updateProducto(p);
                            } else {
                              cubit.addProducto(p);
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Producto producto) {
    // Los diálogos no quedan debajo del BlocProvider: se toma el Cubit acá.
    final cubit = context.read<InventarioCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text(
            'Se desincorporará "${producto.nombre}" (${producto.id}) del inventario.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              cubit.deleteProducto(producto.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

/// Control de foto simple: previsualización + tomar/elegir/descargar/quitar,
/// sin que el usuario tenga que ver ni escribir rutas o IDs de Drive. Subir
/// una foto nueva SIEMPRE crea una fila nueva en "galeria" — nunca se pisa
/// ni se borra una foto existente (ver
/// [SheetsDataService.subirFotoGaleria]), así que una foto que ya usó un
/// producto vendido nunca se pierde. La subida y la asignación viven en
/// [FotoProductoCubit].
class _FotoPicker extends StatelessWidget {
  final String? fotoId;
  final SheetsDataService dataService;

  /// Producto ya existente: la foto se le asigna en Sheets (aunque se
  /// cierre la pantalla durante la subida).
  final String? productoId;

  /// Formulario: avisa la foto elegida, que se guarda con el producto.
  final ValueChanged<String?>? onChanged;

  const _FotoPicker({
    required this.fotoId,
    required this.dataService,
    this.productoId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FotoProductoCubit(dataService: dataService, fotoIdInicial: fotoId, productoId: productoId),
      child: _FotoPickerView(onChanged: onChanged),
    );
  }
}

class _FotoPickerView extends StatelessWidget {
  final ValueChanged<String?>? onChanged;

  const _FotoPickerView({this.onChanged});

  Future<void> _tomarOElegir(BuildContext context, ImageSource source) async {
    final cubit = context.read<FotoProductoCubit>();
    final messenger = ScaffoldMessenger.of(context);
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(source == ImageSource.camera ? 'No se pudo abrir la cámara.' : 'No se pudo abrir la galería.'),
        backgroundColor: AppPalette.error,
      ));
      return;
    }
    if (picked == null) return; // el usuario canceló
    await cubit.subir(
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
      mimeType: picked.mimeType ?? 'image/jpeg',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FotoProductoCubit, FotoProductoState>(
          listenWhen: (prev, curr) => prev.fotoId != curr.fotoId,
          listener: (context, state) => onChanged?.call(state.fotoId),
        ),
        BlocListener<FotoProductoCubit, FotoProductoState>(
          listenWhen: (prev, curr) => curr.mensaje != null && prev.mensaje != curr.mensaje,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.mensaje!),
              backgroundColor: state.mensajeEsError ? AppPalette.error : null,
            ));
            context.read<FotoProductoCubit>().mensajeMostrado();
          },
        ),
      ],
      child: BlocBuilder<FotoProductoCubit, FotoProductoState>(
        builder: (context, state) => _build(context, state),
      ),
    );
  }

  Widget _build(BuildContext context, FotoProductoState state) {
    final cubit = context.read<FotoProductoCubit>();
    final procesando = state.procesando;
    final url = state.fotoUrl;
    final mensajeProceso = switch (state.status) {
      FotoProductoStatus.subiendo => 'Subiendo foto...',
      FotoProductoStatus.verificando => 'Verificando foto...',
      FotoProductoStatus.descargando => 'Descargando foto...',
      FotoProductoStatus.listo => '',
    };

    return Column(
      children: [
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border, width: 1.5),
            ),
            child: procesando
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CupertinoActivityIndicator(),
                        const SizedBox(height: 6),
                        Text(
                          mensajeProceso,
                          style: AppTypography.labelSmall.copyWith(fontSize: 10, color: AppPalette.textSecondary),
                        ),
                      ],
                    ),
                  )
                : state.tieneFoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          url!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CupertinoActivityIndicator());
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(CupertinoIcons.exclamationmark_circle, color: AppPalette.warning, size: 28),
                          ),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.photo, color: AppPalette.blue400, size: 36),
                            SizedBox(height: 4),
                            Text('Sin foto asignada', style: TextStyle(fontSize: 11, color: AppPalette.textSecondary)),
                          ],
                        ),
                      ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            AppOutlinedButton(
              label: 'Tomar foto',
              icon: CupertinoIcons.camera,
              onPressed: procesando ? null : () => _tomarOElegir(context, ImageSource.camera),
            ),
            AppOutlinedButton(
              label: 'Galería',
              icon: CupertinoIcons.photo,
              onPressed: procesando ? null : () => _tomarOElegir(context, ImageSource.gallery),
            ),
            if (state.tieneFoto)
              AppOutlinedButton(
                label: 'Descargar',
                icon: CupertinoIcons.arrow_down_circle,
                onPressed: procesando ? null : cubit.descargar,
              ),
            if (state.tieneFoto)
              AppOutlinedButton(
                label: 'Quitar',
                icon: CupertinoIcons.xmark,
                onPressed: procesando ? null : cubit.quitar,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Las fotos de productos se publican por enlace (ver organizarDrive
        // en google_apps_script.js): nada privado debe subirse por acá.
        Text(
          'La foto se publica junto al producto. No subas documentos, facturas ni fotos personales.',
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
        ),
      ],
    );
  }
}
