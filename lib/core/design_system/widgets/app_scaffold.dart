import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Scaffold base minimalista con AppBar sobria y borde divisor sutil.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: showBackButton,
        title: Text(
          title,
          style: AppTypography.headlineMedium,
        ),
        actions: actions != null
            ? [
                ...actions!,
                const SizedBox(width: 8),
              ]
            : null,
        shape: const Border(
          bottom: BorderSide(color: AppPalette.divider, width: 1),
        ),
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
