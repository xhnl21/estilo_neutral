import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de inventario en [InventarioPage].
class InventarioSkeleton extends StatelessWidget {
  final int itemCount;

  const InventarioSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          80,
        ),
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SkeletonCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Imagen / Foto thumbnail placeholder
                  SkeletonBox(
                    width: 56,
                    height: 56,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  SizedBox(width: AppSpacing.md),
                  // Detalle del producto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine.caption(width: 60),
                        SizedBox(height: 6),
                        SkeletonLine.title(width: 150),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            SkeletonBox(width: 50, height: 18),
                            SizedBox(width: 6),
                            SkeletonBox(width: 45, height: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  // Precio y stock
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SkeletonLine.subtitle(width: 65),
                      SizedBox(height: 6),
                      SkeletonBox(width: 55, height: 20),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
