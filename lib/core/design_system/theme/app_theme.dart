import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';

/// Tema Material 3 adaptado a la estética minimalista y paleta azul de Estilo Neutral.
abstract final class AppTheme {
  /// Tema Claro Oficial (Light)
  static ThemeData get light {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.blue700,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppPalette.blue700,
      onPrimary: AppPalette.surface,
      primaryContainer: AppPalette.blue100,
      onPrimaryContainer: AppPalette.blue900,
      secondary: AppPalette.blue400,
      onSecondary: AppPalette.blue900,
      surface: AppPalette.surface,
      onSurface: AppPalette.textPrimary,
      outline: AppPalette.border,
      outlineVariant: AppPalette.divider,
      error: AppPalette.error,
      onError: AppPalette.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: AppPalette.surface,
      textTheme: AppTypography.createTextTheme(),

      // AppBar minimalista: elevación 0, borde sutil inferior
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineMedium,
        iconTheme: const IconThemeData(color: AppPalette.blue700, size: 24),
        actionsIconTheme: const IconThemeData(color: AppPalette.blue700, size: 24),
        shape: const Border(
          bottom: BorderSide(color: AppPalette.divider, width: 1),
        ),
      ),

      // Card minimalista: fondo blanco azulado, borde sutil
      cardTheme: const CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedMd,
          side: BorderSide(color: AppPalette.border, width: 1),
        ),
      ),

      // Botón Primario: azul medio #4D82BC, pill radius
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.blue700,
          foregroundColor: AppPalette.surface,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: AppSpacing.pxLg,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedPill,
          ),
          textStyle: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Botón Secundario: outlined en azul medio
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.blue700,
          side: const BorderSide(color: AppPalette.blue700, width: 1),
          minimumSize: const Size(0, 48),
          padding: AppSpacing.pxLg,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedPill,
          ),
          textStyle: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Botón de Texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.blue700,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedPill,
          ),
          textStyle: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs minimalistas: sin sombras, bordes precisos
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: AppSpacing.roundedSm,
          borderSide: BorderSide(color: AppPalette.border, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppSpacing.roundedSm,
          borderSide: BorderSide(color: AppPalette.border, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppSpacing.roundedSm,
          borderSide: BorderSide(color: AppPalette.blue700, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppSpacing.roundedSm,
          borderSide: BorderSide(color: AppPalette.error, width: 1),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppSpacing.roundedSm,
          borderSide: BorderSide(color: AppPalette.error, width: 1.5),
        ),
        labelStyle: AppTypography.bodyMedium,
        floatingLabelStyle: AppTypography.labelSmall.copyWith(color: AppPalette.blue700),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppPalette.textDisabled),
      ),

      // Chips semánticos y de estado
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.blue100,
        labelStyle: AppTypography.labelSmall.copyWith(color: AppPalette.blue900),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedPill,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.blue700,
        foregroundColor: AppPalette.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
      ),

      // NavigationBar minimalista
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        indicatorColor: AppPalette.blue100,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: AppPalette.blue700,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: AppPalette.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.blue700, size: 24);
          }
          return const IconThemeData(color: AppPalette.textSecondary, size: 24);
        }),
      ),

      // Divisores
      dividerTheme: const DividerThemeData(
        color: AppPalette.divider,
        thickness: 1,
        space: 1,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.blue900,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppPalette.surface),
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedMd,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Diálogos
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedLg,
          side: BorderSide(color: AppPalette.border, width: 1),
        ),
        titleTextStyle: AppTypography.titleLarge,
        contentTextStyle: AppTypography.bodyMedium,
      ),
    );
  }

  /// Tema Oscuro Invertido Coherente (Dark)
  static ThemeData get dark {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.blue700,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppPalette.blue400,
      onPrimary: AppPalette.blue900,
      primaryContainer: AppPalette.blue900,
      onPrimaryContainer: AppPalette.surface,
      secondary: AppPalette.blue100,
      surface: AppPalette.blue900,
      onSurface: AppPalette.surface,
      outline: AppPalette.blue700,
      error: AppPalette.error,
      onError: AppPalette.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: AppPalette.blue900,
      textTheme: AppTypography.createTextTheme().apply(
        bodyColor: AppPalette.surface,
        displayColor: AppPalette.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.blue900,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.surface),
      ),
    );
  }
}
