import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Campo de texto minimalista sin sombras, con borde sutil y estados accesibles.
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool readOnly;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      style: AppTypography.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: AppPalette.textSecondary)
            : null,
        suffix: suffix,
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
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
        floatingLabelStyle: AppTypography.labelSmall.copyWith(
          color: AppPalette.blue700,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppPalette.textDisabled),
      ),
    );
  }
}
