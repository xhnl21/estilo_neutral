import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/design_system.dart';
import '../../models/cuenta_bancaria.dart';
import '../../models/documento_identidad.dart';
import '../../shared/google_sheets/sheets_data_service.dart';
import '../cubits/datos_bancarios/cuenta_bancaria_form_cubit.dart';
import '../cubits/datos_bancarios/datos_bancarios_cubit.dart';
import '../cubits/datos_bancarios/datos_bancarios_state.dart';

/// Vista "Datos bancarios" (hojas cuentas_bancarias y bancos): las cuentas
/// para transferencias y los pagos móviles de la organización actual.
class DatosBancariosPage extends StatelessWidget {
  final SheetsDataService dataService;

  const DatosBancariosPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DatosBancariosCubit(dataService: dataService),
      child: const _DatosBancariosView(),
    );
  }
}

class _DatosBancariosView extends StatelessWidget {
  const _DatosBancariosView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DatosBancariosCubit, DatosBancariosState>(
      listenWhen: (prev, curr) =>
          (curr.actionSuccessMessage != null && prev.actionSuccessMessage != curr.actionSuccessMessage) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        final ok = state.actionSuccessMessage != null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.actionSuccessMessage ?? state.errorMessage!),
          backgroundColor: ok ? AppPalette.success : AppPalette.error,
          duration: Duration(seconds: ok ? 2 : 4),
        ));
      },
      builder: (context, state) {
        final cubit = context.read<DatosBancariosCubit>();
        final cargando = state.status == DatosBancariosStatus.loading;
        return AppScaffold(
          title: 'Datos bancarios',
          subtitle: 'Cuentas y pago móvil de la organización',
          actions: [AppRefreshButton(onRefresh: cubit.refresh, isRefreshing: cargando)],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'nuevo_dato_bancario',
            onPressed: () => _abrirFormulario(context),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Nuevo'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.cuentas.isNotEmpty) _filtros(cubit, state),
              Expanded(child: _lista(context, state, cargando)),
            ],
          ),
        );
      },
    );
  }

  Widget _filtros(DatosBancariosCubit cubit, DatosBancariosState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('Todos (${state.cuentas.length})'),
            selected: state.filtroTipo == null,
            onSelected: (_) => cubit.filtrarPorTipo(null),
          ),
          for (final t in TipoCuentaBancaria.values) ...[
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              label: Text('${t.etiqueta} (${state.cantidad(t)})'),
              selected: state.filtroTipo == t,
              onSelected: (_) => cubit.filtrarPorTipo(state.filtroTipo == t ? null : t),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lista(BuildContext context, DatosBancariosState state, bool cargando) {
    if (state.cuentas.isEmpty && cargando) return const AppLoadingState();
    if (state.cuentas.isEmpty) {
      return AppEmptyState(
        title: 'Sin datos bancarios',
        subtitle: 'Registrá las cuentas para transferencias y el pago móvil de la organización.',
        icon: CupertinoIcons.creditcard,
        actionLabel: 'Nuevo dato bancario',
        onAction: () => _abrirFormulario(context),
      );
    }
    final cuentas = state.filtradas;
    if (cuentas.isEmpty) {
      return AppEmptyState(
        title: 'No hay datos de este tipo',
        icon: CupertinoIcons.line_horizontal_3_decrease,
        actionLabel: 'Ver todos',
        onAction: () => context.read<DatosBancariosCubit>().filtrarPorTipo(null),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
      itemCount: cuentas.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _TarjetaCuenta(cuenta: cuentas[i], banco: state.bancos[cuentas[i].bancoId]),
    );
  }
}

String _documentoLegible(CuentaBancaria c) => DocumentoIdentidad.formatear(c.tipoDocumento, c.documento);

class _TarjetaCuenta extends StatelessWidget {
  final CuentaBancaria cuenta;
  final Banco? banco;

  const _TarjetaCuenta({required this.cuenta, required this.banco});

  @override
  Widget build(BuildContext context) {
    final esPagoMovil = cuenta.tipo == TipoCuentaBancaria.pagoMovil;
    final dato = esPagoMovil ? cuenta.telefonoLegible : cuenta.numeroCuentaLegible;
    final estiloBoton = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppPalette.border),
    );
    return AppCard(
      semanticLabel: '${cuenta.tipo.etiqueta}, ${banco?.nombre ?? 'banco desconocido'}, $dato, ${cuenta.titular}'
          '${cuenta.activa ? '' : ', inactivo'}',
      mergeSemantics: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppPalette.blue100,
                  child: Icon(esPagoMovil ? CupertinoIcons.device_phone_portrait : CupertinoIcons.building_2_fill,
                      color: AppPalette.blue700, size: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(banco?.nombre ?? 'Banco ${cuenta.bancoId}',
                        style: AppTypography.titleLarge.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(dato,
                        style: AppTypography.bodyMedium.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${cuenta.titular} · ${_documentoLegible(cuenta)}',
              style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(label: cuenta.tipo.etiqueta),
              if (cuenta.modalidad case final m?) AppChip(label: 'Cuenta ${m.etiqueta.toLowerCase()}'),
              if (!cuenta.activa) const AppChip(label: 'Inactivo', variant: AppChipVariant.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: estiloBoton.copyWith(foregroundColor: const WidgetStatePropertyAll(AppPalette.blue700)),
                icon: const Icon(CupertinoIcons.eye, size: 16),
                label: const Text('Ver'),
                onPressed: () => _ver(context),
              ),
              OutlinedButton.icon(
                style: estiloBoton.copyWith(foregroundColor: const WidgetStatePropertyAll(AppPalette.blue700)),
                icon: const Icon(CupertinoIcons.pencil, size: 16),
                label: const Text('Editar'),
                onPressed: () => _abrirFormulario(context, cuenta: cuenta),
              ),
              OutlinedButton.icon(
                style: estiloBoton.copyWith(foregroundColor: const WidgetStatePropertyAll(AppPalette.error)),
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('Eliminar'),
                onPressed: () => _confirmarEliminar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _ver(BuildContext context) {
    final cubit = context.read<DatosBancariosCubit>();
    final texto = cuenta.textoParaCompartir(banco: banco, documentoLegible: _documentoLegible(cuenta));
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(cuenta.tipo.etiqueta, style: AppTypography.titleLarge.copyWith(fontSize: 18)),
              const SizedBox(height: AppSpacing.md),
              AppCard(child: SelectableText(texto, style: AppTypography.bodyMedium.copyWith(height: 1.5))),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Copiar datos',
                icon: CupertinoIcons.doc_on_clipboard,
                isFullWidth: true,
                onPressed: () async {
                  final mensajero = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: texto));
                  if (ctx.mounted) Navigator.pop(ctx);
                  mensajero.showSnackBar(const SnackBar(
                    content: Text('Datos copiados: pegalos en el chat con el cliente.'),
                    duration: Duration(seconds: 2),
                  ));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: Icon(cuenta.activa ? CupertinoIcons.pause_circle : CupertinoIcons.play_circle, size: 18),
                label: Text(cuenta.activa ? 'Inactivar' : 'Activar'),
                onPressed: () {
                  Navigator.pop(ctx);
                  cubit.cambiarEstado(cuenta, activa: !cuenta.activa);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    final cubit = context.read<DatosBancariosCubit>();
    final dato = cuenta.tipo == TipoCuentaBancaria.pagoMovil ? cuenta.telefonoLegible : cuenta.numeroCuentaLegible;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar dato bancario?'),
        content: Text('Se elimina ${cuenta.tipo.etiqueta.toLowerCase()} de ${banco?.nombre ?? 'este banco'} ($dato).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            onPressed: () {
              Navigator.pop(ctx);
              cubit.eliminar(cuenta);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

void _abrirFormulario(BuildContext context, {CuentaBancaria? cuenta}) {
  final dataService = context.read<DatosBancariosCubit>().dataService;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BlocProvider(
      create: (_) => CuentaBancariaFormCubit(dataService: dataService, cuenta: cuenta),
      child: const _FormularioCuenta(),
    ),
  );
}

/// Formulario de un dato bancario. Solo los `TextEditingController` viven en
/// el widget; tipo, banco, documento, modalidad, validación y guardado, en
/// [CuentaBancariaFormCubit].
class _FormularioCuenta extends StatefulWidget {
  const _FormularioCuenta();

  @override
  State<_FormularioCuenta> createState() => _FormularioCuentaState();
}

class _FormularioCuentaState extends State<_FormularioCuenta> {
  late final TextEditingController _titular;
  late final TextEditingController _documento;
  late final TextEditingController _cuenta;
  late final TextEditingController _telefono;

  @override
  void initState() {
    super.initState();
    final c = context.read<CuentaBancariaFormCubit>().cuenta;
    _titular = TextEditingController(text: c?.titular ?? '');
    _documento = TextEditingController(text: c?.documento ?? '');
    _cuenta = TextEditingController(text: c?.numeroCuenta ?? '');
    _telefono = TextEditingController(text: (c?.telefono.length ?? 0) == 11 ? c!.telefono.substring(4) : '');
  }

  @override
  void dispose() {
    _titular.dispose();
    _documento.dispose();
    _cuenta.dispose();
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CuentaBancariaFormCubit>();
    return BlocConsumer<CuentaBancariaFormCubit, CuentaBancariaFormState>(
      listenWhen: (prev, curr) =>
          (curr.guardada && !prev.guardada) || (curr.errorMessage != null && curr.errorMessage != prev.errorMessage),
      listener: (context, state) {
        final mensajero = ScaffoldMessenger.of(context);
        if (state.guardada) {
          Navigator.of(context).pop();
          mensajero.showSnackBar(SnackBar(
            content: Text(cubit.esEdicion ? 'Dato bancario actualizado.' : 'Dato bancario guardado.'),
            backgroundColor: AppPalette.success,
            duration: const Duration(seconds: 2),
          ));
        } else {
          mensajero.showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppPalette.error,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        final ocupado = state.guardando;
        final transferencia = state.tipo == TipoCuentaBancaria.transferencia;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(cubit.esEdicion ? 'Editar dato bancario' : 'Nuevo dato bancario',
                    style: AppTypography.titleLarge.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<TipoCuentaBancaria>(
                  segments: const [
                    ButtonSegment(
                        value: TipoCuentaBancaria.transferencia,
                        label: Text('Transferencia'),
                        icon: Icon(CupertinoIcons.building_2_fill)),
                    ButtonSegment(
                        value: TipoCuentaBancaria.pagoMovil,
                        label: Text('Pago móvil'),
                        icon: Icon(CupertinoIcons.device_phone_portrait)),
                  ],
                  selected: {state.tipo},
                  onSelectionChanged: ocupado ? null : (s) => cubit.elegirTipo(s.first),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: ValueKey('banco-${state.bancoId}-${state.bancos.length}'),
                  initialValue: state.banco?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Banco',
                    errorText: state.errores[CampoCuenta.banco],
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final b in state.bancos)
                      DropdownMenuItem(value: b.id, child: Text(b.etiqueta, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: ocupado ? null : (id) => id == null ? null : cubit.elegirBanco(id),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Titular',
                  controller: _titular,
                  hint: 'Ej: Estilo Neutral C.A.',
                  readOnly: ocupado,
                  textCapitalization: TextCapitalization.words,
                  errorText: state.errores[CampoCuenta.titular],
                  onChanged: (_) => cubit.campoEditado(CampoCuenta.titular),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      // Sin label visible (lo explica el campo de al lado);
                      // el lector de pantalla sí lo anuncia.
                      child: Semantics(
                        label: 'Tipo de documento',
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('doc-${state.tipoDocumento}'),
                          initialValue: state.tipoDocumento,
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: [for (final t in state.tiposDocumento) DropdownMenuItem(value: t, child: Text(t))],
                          onChanged: ocupado ? null : (t) => t == null ? null : cubit.elegirTipoDocumento(t),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        label: 'Cédula / RIF',
                        controller: _documento,
                        hint: state.tipoDocumento == 'J' || state.tipoDocumento == 'G' ? '12345678-9' : '12345678',
                        readOnly: ocupado,
                        errorText: state.errores[CampoCuenta.documento],
                        onChanged: (_) => cubit.campoEditado(CampoCuenta.documento),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (transferencia) ...[
                  AppTextField(
                    label: 'Número de cuenta (20 dígitos)',
                    controller: _cuenta,
                    hint: '${state.banco?.codigo ?? '0000'}-0000-00-0000000000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d -]'))],
                    readOnly: ocupado,
                    errorText: state.errores[CampoCuenta.numeroCuenta],
                    onChanged: (_) => cubit.campoEditado(CampoCuenta.numeroCuenta),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Tipo de cuenta', style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<ModalidadCuenta>(
                    emptySelectionAllowed: true,
                    segments: [
                      for (final m in ModalidadCuenta.values) ButtonSegment(value: m, label: Text(m.etiqueta)),
                    ],
                    selected: {if (state.modalidad case final m?) m},
                    onSelectionChanged: ocupado ? null : (s) => s.isEmpty ? null : cubit.elegirModalidad(s.first),
                  ),
                  if (state.errores[CampoCuenta.modalidad] case final e?)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(e, style: AppTypography.labelSmall.copyWith(color: AppPalette.error)),
                    ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 124,
                        child: Semantics(
                          label: 'Código de operadora',
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('cod-${state.codigoTelefono}'),
                            initialValue: state.codigoTelefono,
                            isExpanded: true,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: [for (final c in state.codigosTelefono) DropdownMenuItem(value: c, child: Text(c))],
                            onChanged: ocupado ? null : (c) => c == null ? null : cubit.elegirCodigoTelefono(c),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          label: 'Teléfono',
                          controller: _telefono,
                          hint: '1234567',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          readOnly: ocupado,
                          errorText: state.errores[CampoCuenta.telefono],
                          onChanged: (_) => cubit.campoEditado(CampoCuenta.telefono),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  subtitle: const Text('Los inactivos quedan guardados, pero marcados.'),
                  value: state.activa,
                  onChanged: ocupado ? null : cubit.cambiarActiva,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Guardar',
                  icon: CupertinoIcons.checkmark_alt,
                  isLoading: ocupado,
                  isFullWidth: true,
                  onPressed: ocupado
                      ? null
                      : () => cubit.guardar(
                            titular: _titular.text,
                            documento: _documento.text,
                            numeroCuenta: _cuenta.text,
                            numeroTelefono: _telefono.text,
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
