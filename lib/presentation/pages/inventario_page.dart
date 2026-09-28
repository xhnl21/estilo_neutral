import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/network/dio_client.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
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
            label: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showProductoDialog(context),
          ),
          body: Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
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
                  child: (state.status == InventarioStatus.loading && state.productos.isEmpty)
                      ? const InventarioSkeleton(
                          key: ValueKey('inventario_skeleton'),
                        )
                      : productos.isEmpty
                          ? const AppEmptyState(
                              key: ValueKey('inventario_empty'),
                              title: 'No hay productos en inventario',
                              description: 'Registra prendas usando el botón "Nuevo Producto".',
                              icon: CupertinoIcons.tag,
                            )
                          : ListView(
                              key: const ValueKey('inventario_list'),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                              children: [
                                ExpansionPanelList(
                                  elevation: 1,
                                  expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 4),
                                  expansionCallback: (panelIndex, isExpanded) {
                                    final producto = productos[panelIndex];
                                    cubit.toggleExpanded(producto.id);
                                  },
                                  children: productos.map<ExpansionPanel>((producto) {
                                    final isDepleted = producto.cantidad <= 0;
                                    final isLowStock = producto.cantidad > 0 && producto.cantidad <= 3;
                                    final fotoUrl = widget.dataService.fotoUrlPorId(producto.fotoId);
                                    final hasPhoto = fotoUrl != null && fotoUrl.isNotEmpty;
                                    final isExpanded = state.expandedProductoId == producto.id;

                                    return ExpansionPanel(
                                      isExpanded: isExpanded,
                                      canTapOnHeader: true,
                                      backgroundColor: AppPalette.surface,
                                      headerBuilder: (context, isHeaderExpanded) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                          child: Row(
                                            children: [
                                              // Miniatura foto
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: AppPalette.blue100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: hasPhoto
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.network(
                                                          fotoUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => const Center(
                                                            child: Icon(CupertinoIcons.photo, color: AppPalette.blue700, size: 20),
                                                          ),
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: Icon(CupertinoIcons.tag_fill, color: AppPalette.blue700, size: 20),
                                                      ),
                                              ),
                                              const SizedBox(width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      producto.nombre,
                                                      style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                                      maxLines: isHeaderExpanded ? null : 1,
                                                      overflow: isHeaderExpanded ? null : TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 6,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        Text(
                                                          'ID: ${producto.id}',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            color: AppPalette.textSecondary,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        AppChip(
                                                          label: isDepleted
                                                              ? 'Agotado'
                                                              : (isLowStock ? 'Bajo stock (${producto.cantidad})' : 'Stock: ${producto.cantidad}'),
                                                          variant: isDepleted
                                                              ? AppChipVariant.error
                                                              : (isLowStock ? AppChipVariant.warning : AppChipVariant.success),
                                                        ),
                                                        AppMoneyText(
                                                          amount: producto.precioUsd,
                                                          currency: MoneyCurrency.usd,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
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
                                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(color: AppPalette.divider),
                                            const SizedBox(height: 4),
                                            SelectableText.rich(
                                              TextSpan(
                                                style: AppTypography.bodyMedium.copyWith(fontSize: 13, height: 1.5),
                                                children: [
                                                  const TextSpan(text: '🏷️ Marca: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: producto.marca.isNotEmpty ? producto.marca : 'Sin marca'),
                                                  const TextSpan(text: '\n👗 Modelo: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: producto.modelo.isNotEmpty ? producto.modelo : 'Sin modelo'),
                                                  const TextSpan(text: '\n📏 Talla: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: producto.talla.isNotEmpty ? producto.talla : 'Única'),
                                                  const TextSpan(text: '\n🏢 Organización: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: producto.organizacionId),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              alignment: WrapAlignment.spaceBetween,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: AppSpacing.sm,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Ajustar existencias: ',
                                                      style: AppTypography.labelSmall.copyWith(
                                                        color: AppPalette.textSecondary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    IconButton.filledTonal(
                                                      iconSize: 14,
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                      icon: const Icon(CupertinoIcons.minus),
                                                      tooltip: 'Reducir stock',
                                                      onPressed: isDepleted
                                                          ? null
                                                          : () => widget.dataService.adjustStock(producto.id, -1),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      child: Text(
                                                        '${producto.cantidad}',
                                                        style: AppTypography.titleLarge.copyWith(fontSize: 14),
                                                      ),
                                                    ),
                                                    IconButton.filledTonal(
                                                      iconSize: 14,
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                      icon: const Icon(CupertinoIcons.plus),
                                                      tooltip: 'Aumentar stock',
                                                      onPressed: () => widget.dataService.adjustStock(producto.id, 1),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.blue700,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.photo_camera, size: 16),
                                                  label: const Text('Foto'),
                                                  onPressed: () => _showFotoActionSheet(context, producto),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.blue700,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.pencil, size: 16),
                                                  label: const Text('Editar'),
                                                  onPressed: () => _showProductoDialog(context, producto: producto),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.error,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.trash, size: 16),
                                                  label: const Text('Eliminar'),
                                                  onPressed: () => _confirmDelete(context, producto),
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
    var fotoIdActual = producto.fotoId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _FotoPicker(
                fotoId: fotoIdActual,
                dataService: widget.dataService,
                onChanged: (nuevoFotoId) {
                  setModalState(() => fotoIdActual = nuevoFotoId);
                  final actualizado = Producto(
                    id: producto.id,
                    cantidad: producto.cantidad,
                    nombre: producto.nombre,
                    marca: producto.marca,
                    modelo: producto.modelo,
                    talla: producto.talla,
                    precioUsd: producto.precioUsd,
                    fotoId: nuevoFotoId,
                    organizacionId: producto.organizacionId,
                  );
                  widget.dataService.updateProducto(actualizado);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductoDialog(BuildContext context, {Producto? producto}) {
    final isEditing = producto != null;
    final id = isEditing ? producto.id : widget.dataService.nextProductoId;
    final nombreController = TextEditingController(text: producto?.nombre ?? '');
    final marcaController = TextEditingController(text: producto?.marca ?? 'Genérica');
    final modeloController = TextEditingController(text: producto?.modelo ?? 'Casual');
    final tallaController = TextEditingController(text: producto?.talla ?? 'M');
    final cantidadController = TextEditingController(text: producto?.cantidad.toString() ?? '10');
    final precioController = TextEditingController(text: producto?.precioUsd.toStringAsFixed(2) ?? '20.00');
    var pendingFotoId = producto?.fotoId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                      Text(
                        isEditing ? 'Editar Producto ($id)' : 'Registrar Nuevo Producto',
                        style: AppTypography.titleLarge.copyWith(fontSize: 17),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FotoPicker(
                    fotoId: pendingFotoId,
                    dataService: widget.dataService,
                    onChanged: (nuevoFotoId) => setModalState(() => pendingFotoId = nuevoFotoId),
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
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'Modelo',
                          controller: modeloController,
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
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Precio Unitario (USD)',
                    controller: precioController,
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
                          onPressed: () {
                            final nombre = nombreController.text.trim();
                            if (nombre.isEmpty) return;

                            final p = Producto(
                              id: id,
                              cantidad: int.tryParse(cantidadController.text) ?? 0,
                              nombre: nombre,
                              marca: marcaController.text.trim(),
                              modelo: modeloController.text.trim(),
                              talla: tallaController.text.trim(),
                              precioUsd: double.tryParse(precioController.text.replaceAll(',', '.')) ?? 0.0,
                              fotoId: pendingFotoId,
                            );

                            if (isEditing) {
                              widget.dataService.updateProducto(p);
                            } else {
                              widget.dataService.addProducto(p);
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('Se desincorporará "${producto.nombre}" (${producto.id}) del inventario.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              widget.dataService.deleteProducto(producto.id);
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
/// producto vendido nunca se pierde.
class _FotoPicker extends StatefulWidget {
  final String? fotoId;
  final SheetsDataService dataService;
  final ValueChanged<String?> onChanged;

  const _FotoPicker({
    required this.fotoId,
    required this.dataService,
    required this.onChanged,
  });

  @override
  State<_FotoPicker> createState() => _FotoPickerState();
}

class _FotoPickerState extends State<_FotoPicker> {
  final Dio _dio = DioClient().dio;
  bool _procesando = false;
  String? _procesandoMensaje;

  void _mostrarInfo(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppPalette.error),
    );
  }

  Future<void> _tomarOElegir(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    } catch (_) {
      _mostrarError(
        source == ImageSource.camera ? 'No se pudo abrir la cámara.' : 'No se pudo abrir la galería.',
      );
      return;
    }
    if (picked == null) return; // el usuario canceló

    setState(() {
      _procesando = true;
      _procesandoMensaje = 'Subiendo foto...';
    });
    try {
      final original = await picked.readAsBytes();
      var bytes = original;
      var fileName = picked.name;
      var mimeType = picked.mimeType ?? 'image/jpeg';
      // image_picker ya reduce calidad/dimensiones al elegir la foto, pero
      // eso no aplica a PNG. Se comprime de nuevo acá (a JPEG, sin
      // transparencia real en fotos de productos) para bajar el peso del
      // payload en base64 — más chico, más rápido y menos probable de pisar
      // el timeout de red al subir.
      try {
        final comprimido = await FlutterImageCompress.compressWithList(
          original,
          minWidth: 1600,
          minHeight: 1600,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (comprimido.length < original.length) {
          bytes = comprimido;
          mimeType = 'image/jpeg';
          final sinExtension = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
          fileName = '$sinExtension.jpg';
        }
      } catch (_) {
        // Si la compresión falla (formato no soportado, etc.), seguimos con
        // los bytes originales tal cual venían de image_picker.
      }

      final nuevoFotoId = await widget.dataService.subirFotoGaleria(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      if (!mounted) return;
      if (nuevoFotoId != null) {
        // El CDN público de Drive (lh3.googleusercontent.com) tarda unos
        // segundos en empezar a servir un archivo recién creado; esperamos a
        // que la URL responda antes de mostrarla, para no pintar el ícono de
        // error de entrada aunque la foto ya haya quedado bien guardada.
        setState(() => _procesandoMensaje = 'Verificando foto...');
        await _esperarUrlDisponible(widget.dataService.fotoUrlPorId(nuevoFotoId));
        if (!mounted) return;
        widget.onChanged(nuevoFotoId);
        _mostrarInfo('Foto subida correctamente.');
      } else {
        _mostrarError('No se pudo subir la foto. Probá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _esperarUrlDisponible(String? url) async {
    if (url == null || url.isEmpty) return;
    for (var intento = 0; intento < 5; intento++) {
      try {
        final response = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 5)));
        if (response.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _descargar() async {
    final url = widget.dataService.fotoUrlPorId(widget.fotoId);
    if (url == null || url.isEmpty) return;

    setState(() {
      _procesando = true;
      _procesandoMensaje = 'Descargando foto...';
    });
    try {
      final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      if (response.statusCode != 200 || response.data == null) {
        _mostrarError('No se pudo descargar la foto.');
        return;
      }
      await Gal.putImageBytes(Uint8List.fromList(response.data!));
      _mostrarInfo('Foto guardada en tu galería.');
    } catch (_) {
      _mostrarError('No se pudo descargar la foto.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.dataService.fotoUrlPorId(widget.fotoId);
    final hasPhoto = url != null && url.isNotEmpty;

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
            child: _procesando
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CupertinoActivityIndicator(),
                        const SizedBox(height: 6),
                        Text(
                          _procesandoMensaje ?? '',
                          style: AppTypography.labelSmall.copyWith(fontSize: 10, color: AppPalette.textSecondary),
                        ),
                      ],
                    ),
                  )
                : hasPhoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          url,
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
              onPressed: _procesando ? null : () => _tomarOElegir(ImageSource.camera),
            ),
            AppOutlinedButton(
              label: 'Galería',
              icon: CupertinoIcons.photo,
              onPressed: _procesando ? null : () => _tomarOElegir(ImageSource.gallery),
            ),
            if (hasPhoto)
              AppOutlinedButton(
                label: 'Descargar',
                icon: CupertinoIcons.arrow_down_circle,
                onPressed: _procesando ? null : _descargar,
              ),
            if (hasPhoto)
              AppOutlinedButton(
                label: 'Quitar',
                icon: CupertinoIcons.xmark,
                onPressed: _procesando ? null : () => widget.onChanged(null),
              ),
          ],
        ),
      ],
    );
  }
}
