import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';

/// Vista de Inventario / Catálogo de Productos (hoja: inventario)
/// La foto de cada producto se toma con la cámara o se elige de la
/// galería del teléfono — el usuario nunca ve rutas ni IDs de Google
/// Drive (ver [_FotoPicker] y [SheetsDataService.subirFotoGaleria]).
class InventarioPage extends StatefulWidget {
  final SheetsDataService dataService;
  final String? initialSearchQuery;

  const InventarioPage({
    super.key,
    required this.dataService,
    this.initialSearchQuery,
  });

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  late String _searchQuery = widget.initialSearchQuery ?? '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final productos = widget.dataService.productos.where((p) {
          final q = _searchQuery.toLowerCase();
          return p.nombre.toLowerCase().contains(q) ||
              p.marca.toLowerCase().contains(q) ||
              p.modelo.toLowerCase().contains(q) ||
              p.talla.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q);
        }).toList();

        return AppScaffold(
          title: 'Inventario',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'inventario',
            userFriendlyText: '${widget.dataService.productos.length} productos registrados',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
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
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Lista de productos con Skeleton progresivo
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: widget.dataService.isLoading
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
                          : ListView.builder(
                              key: const ValueKey('inventario_list'),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final producto = productos[index];
                          final isDepleted = producto.cantidad <= 0;
                          final isLowStock = producto.cantidad > 0 && producto.cantidad <= 3;
                          final fotoUrl = widget.dataService.fotoUrlPorId(producto.fotoId);
                          final hasPhoto = fotoUrl != null && fotoUrl.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Imagen interactiva con acceso directo a actualización
                                  Semantics(
                                    button: true,
                                    label: 'Actualizar foto de ${producto.nombre}',
                                    hint: 'Toca dos veces para tomar, elegir o descargar la foto',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showFotoActionSheet(context, producto),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
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
                                                        child: ExcludeSemantics(
                                                          child: Icon(
                                                            CupertinoIcons.photo,
                                                            color: AppPalette.blue700,
                                                            size: 22,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: ExcludeSemantics(
                                                      child: Icon(
                                                        CupertinoIcons.tag_fill,
                                                        color: AppPalette.blue700,
                                                        size: 24,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(
                                                color: AppPalette.blue900,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const ExcludeSemantics(
                                                child: Icon(
                                                  CupertinoIcons.camera_fill,
                                                  size: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        MergeSemantics(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      producto.nombre,
                                                      style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: AppSpacing.xs),
                                                  Text(
                                                    '(${producto.id})',
                                                    style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                                  ),
                                                  const SizedBox(width: AppSpacing.sm),
                                                  AppChip(
                                                    label: isDepleted
                                                        ? 'Agotado'
                                                        : (isLowStock ? 'Bajo stock' : 'Stock: ${producto.cantidad}'),
                                                    variant: isDepleted
                                                        ? AppChipVariant.error
                                                        : (isLowStock ? AppChipVariant.warning : AppChipVariant.success),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Marca: ${producto.marca} • Modelo: ${producto.modelo} • Talla: ${producto.talla}',
                                                style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: AppSpacing.xs,
                                          runSpacing: 2,
                                          children: [
                                            AppMoneyText(
                                              amount: producto.precioUsd,
                                              currency: MoneyCurrency.usd,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            // Control rápido de existencias (+ / -)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Semantics(
                                                  button: true,
                                                  enabled: !isDepleted,
                                                  label: 'Reducir stock de ${producto.nombre}',
                                                  child: IconButton.filledTonal(
                                                    iconSize: 14,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    icon: const Icon(CupertinoIcons.minus),
                                                    tooltip: 'Reducir stock',
                                                    onPressed: isDepleted
                                                        ? null
                                                        : () => widget.dataService.adjustStock(producto.id, -1),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  child: Semantics(
                                                    label: 'Stock actual: ${producto.cantidad}',
                                                    child: Text(
                                                      '${producto.cantidad}',
                                                      style: AppTypography.titleLarge.copyWith(fontSize: 13),
                                                    ),
                                                  ),
                                                ),
                                                Semantics(
                                                  button: true,
                                                  enabled: true,
                                                  label: 'Aumentar stock de ${producto.nombre}',
                                                  child: IconButton.filledTonal(
                                                    iconSize: 14,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    icon: const Icon(CupertinoIcons.plus),
                                                    tooltip: 'Aumentar stock',
                                                    onPressed: () => widget.dataService.adjustStock(producto.id, 1),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Acciones de foto, edición y eliminación
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        button: true,
                                        label: 'Cambiar foto de ${producto.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(CupertinoIcons.photo_camera, size: 18, color: AppPalette.blue700),
                                          tooltip: 'Tomar, elegir o descargar foto',
                                          onPressed: () => _showFotoActionSheet(context, producto),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Semantics(
                                        button: true,
                                        label: 'Editar datos de ${producto.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                          tooltip: 'Editar Datos de Producto',
                                          onPressed: () => _showProductoDialog(context, producto: producto),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Semantics(
                                        button: true,
                                        label: 'Eliminar producto ${producto.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                          tooltip: 'Eliminar Producto',
                                          onPressed: () => _confirmDelete(context, producto),
                                        ),
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
      final bytes = await picked.readAsBytes();
      final nuevoFotoId = await widget.dataService.subirFotoGaleria(
        bytes: bytes,
        fileName: picked.name,
        mimeType: picked.mimeType ?? 'image/jpeg',
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
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
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
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _mostrarError('No se pudo descargar la foto.');
        return;
      }
      await Gal.putImageBytes(response.bodyBytes);
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
