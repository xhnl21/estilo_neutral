import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/tokens/typography.dart';
import '../../core/design_system/widgets/app_button.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../../core/design_system/widgets/app_chip.dart';
import '../../core/design_system/widgets/app_empty_state.dart';
import '../../core/design_system/widgets/app_money_text.dart';
import '../../core/design_system/widgets/app_outlined_button.dart';
import '../../core/design_system/widgets/app_refresh_button.dart';
import '../../core/design_system/widgets/app_scaffold.dart';
import '../../core/design_system/widgets/app_text_field.dart';
import '../../models/producto.dart';
import '../../shared/google_drive/google_drive_helper.dart';
import '../../shared/google_sheets/sheets_data_service.dart';

/// Vista de Inventario / Catálogo de Productos (hoja: inventario)
/// Integración directa con Google Drive para almacenamiento, actualización y reemplazo de fotos.
class InventarioPage extends StatefulWidget {
  final SheetsDataService dataService;

  const InventarioPage({super.key, required this.dataService});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  String _searchQuery = '';

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
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.plus_app, size: 20),
            label: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showProductoDialog(context),
          ),
          body: Column(
            children: [
              // Banner informativo de la carpeta de Google Drive
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                child: AppCard(
                  padding: AppSpacing.pSm,
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.folder_badge_person_crop, size: 22, color: AppPalette.blue700),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carpeta Google Drive Oficial',
                              style: AppTypography.titleLarge.copyWith(fontSize: 13, color: AppPalette.blue900),
                            ),
                            Text(
                              'ID: ${GoogleDriveHelper.folderId}',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: AppPalette.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppPalette.blue700),
                        tooltip: 'Copiar enlace de carpeta',
                        onPressed: () async {
                          await GoogleDriveHelper.copyFolderUrl();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enlace de la carpeta copiado al portapapeles.')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.arrow_up_right_square, size: 18, color: AppPalette.blue700),
                        tooltip: 'Abrir carpeta en Google Drive',
                        onPressed: () => GoogleDriveHelper.openFolder(),
                      ),
                    ],
                  ),
                ),
              ),

              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
                child: AppTextField(
                  label: 'Buscar producto',
                  hint: 'Prenda, marca, modelo, talla o ID...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Lista de productos
              Expanded(
                child: productos.isEmpty
                    ? const AppEmptyState(
                        title: 'No hay productos en inventario',
                        description: 'Registra prendas usando el botón "Nuevo Producto".',
                        icon: CupertinoIcons.tag,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final producto = productos[index];
                          final isDepleted = producto.cantidad <= 0;
                          final isLowStock = producto.cantidad > 0 && producto.cantidad <= 3;
                          final hasPhoto = producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Imagen interactiva con acceso directo a actualización
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _showUpdateImageDialog(context, producto),
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
                                                    producto.fotoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(
                                                        CupertinoIcons.photo,
                                                        color: AppPalette.blue700,
                                                        size: 22,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    CupertinoIcons.tag_fill,
                                                    color: AppPalette.blue700,
                                                    size: 24,
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
                                            child: const Icon(
                                              CupertinoIcons.camera_fill,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
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
                                                IconButton.filledTonal(
                                                  iconSize: 14,
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                  icon: const Icon(CupertinoIcons.minus),
                                                  onPressed: isDepleted
                                                      ? null
                                                      : () => widget.dataService.adjustStock(producto.id, -1),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  child: Text(
                                                    '${producto.cantidad}',
                                                    style: AppTypography.titleLarge.copyWith(fontSize: 13),
                                                  ),
                                                ),
                                                IconButton.filledTonal(
                                                  iconSize: 14,
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                  icon: const Icon(CupertinoIcons.plus),
                                                  onPressed: () => widget.dataService.adjustStock(producto.id, 1),
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
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.photo_camera, size: 18, color: AppPalette.blue700),
                                        tooltip: 'Cambiar o actualizar imagen en Google Drive',
                                        onPressed: () => _showUpdateImageDialog(context, producto),
                                      ),
                                      const SizedBox(height: 2),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                        tooltip: 'Editar Datos de Producto',
                                        onPressed: () => _showProductoDialog(context, producto: producto),
                                      ),
                                      const SizedBox(height: 2),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                        tooltip: 'Eliminar Producto',
                                        onPressed: () => _confirmDelete(context, producto),
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

  /// Diálogo especializado para cambiar o actualizar la imagen en Google Drive
  void _showUpdateImageDialog(BuildContext context, Producto producto) {
    var rawInput = producto.fotoUrl ?? '';
    var previewUrl = producto.fotoUrl ?? '';
    final urlController = TextEditingController(text: rawInput);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                        Flexible(
                          child: Text(
                            'Actualizar Imagen: ${producto.nombre}',
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

                    // Card informativa con botón para abrir Google Drive
                    AppCard(
                      padding: AppSpacing.pSm,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.cloud_upload_fill, color: AppPalette.blue700, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Text(
                              'Sube tu foto a la carpeta de Google Drive y pega aquí el enlace o ID.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(CupertinoIcons.arrow_up_right, size: 14),
                            label: const Text('Abrir Drive', style: TextStyle(fontSize: 12)),
                            onPressed: () => GoogleDriveHelper.openFolder(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Previsualización en vivo de la imagen
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppPalette.border, width: 1.5),
                        ),
                        child: previewUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  previewUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(child: CupertinoActivityIndicator());
                                  },
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(CupertinoIcons.exclamationmark_circle, color: AppPalette.warning, size: 28),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sin vista previa\n(Verifica permisos)',
                                          textAlign: TextAlign.center,
                                          style: AppTypography.labelSmall.copyWith(fontSize: 10, color: AppPalette.textSecondary),
                                        ),
                                      ],
                                    ),
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

                    // Campo de entrada de URL o ID
                    AppTextField(
                      label: 'Enlace o ID de Archivo en Google Drive',
                      hint: 'Pega el enlace de compartir o el ID...',
                      controller: urlController,
                      onChanged: (val) {
                        setModalState(() {
                          rawInput = val;
                          previewUrl = GoogleDriveHelper.formatDirectImageUrl(val);
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Formato detectado: ${previewUrl.isNotEmpty ? previewUrl : "Esperando enlace..."}',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppPalette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Botones de acción
                    Row(
                      children: [
                        if (producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: IconButton(
                              icon: const Icon(CupertinoIcons.trash, color: AppPalette.error),
                              tooltip: 'Quitar foto',
                              onPressed: () {
                                final updated = Producto(
                                  id: producto.id,
                                  cantidad: producto.cantidad,
                                  nombre: producto.nombre,
                                  marca: producto.marca,
                                  modelo: producto.modelo,
                                  talla: producto.talla,
                                  precioUsd: producto.precioUsd,
                                  fotoUrl: null,
                                );
                                widget.dataService.updateProducto(updated);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        Expanded(
                          child: AppOutlinedButton(
                            label: 'Cancelar',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppButton(
                            label: 'Guardar Imagen',
                            icon: CupertinoIcons.check_mark,
                            onPressed: () {
                              final formatted = GoogleDriveHelper.formatDirectImageUrl(urlController.text.trim());
                              final updated = Producto(
                                id: producto.id,
                                cantidad: producto.cantidad,
                                nombre: producto.nombre,
                                marca: producto.marca,
                                modelo: producto.modelo,
                                talla: producto.talla,
                                precioUsd: producto.precioUsd,
                                fotoUrl: formatted.isNotEmpty ? formatted : null,
                              );
                              widget.dataService.updateProducto(updated);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Imagen de "${producto.nombre}" actualizada con éxito.')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    final fotoUrlController = TextEditingController(text: producto?.fotoUrl ?? '');
    var currentPreview = producto?.fotoUrl ?? '';

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
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Enlace o ID de Foto (Google Drive)',
                    controller: fotoUrlController,
                    hint: 'Pega el enlace o ID de Drive...',
                    onChanged: (val) {
                      setModalState(() {
                        currentPreview = GoogleDriveHelper.formatDirectImageUrl(val);
                      });
                    },
                  ),
                  if (currentPreview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            currentPreview,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 24, color: AppPalette.blue400),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Formato directo generado para Sheets: $currentPreview',
                            style: AppTypography.labelSmall.copyWith(fontSize: 10, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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

                            final rawUrl = fotoUrlController.text.trim();
                            final directUrl = rawUrl.isNotEmpty ? GoogleDriveHelper.formatDirectImageUrl(rawUrl) : null;

                            final p = Producto(
                              id: id,
                              cantidad: int.tryParse(cantidadController.text) ?? 0,
                              nombre: nombre,
                              marca: marcaController.text.trim(),
                              modelo: modeloController.text.trim(),
                              talla: tallaController.text.trim(),
                              precioUsd: double.tryParse(precioController.text.replaceAll(',', '.')) ?? 0.0,
                              fotoUrl: directUrl,
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
