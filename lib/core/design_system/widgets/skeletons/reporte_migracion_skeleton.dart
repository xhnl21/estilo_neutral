import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de reporte de migración en [ReporteMigracionPage].
class ReporteMigracionSkeleton extends StatelessWidget {
  final int itemCount;

  const ReporteMigracionSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          80,
        ),
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLine.subtitle(width: 150),
                      SkeletonBox(width: 70, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLine.body(width: 110),
                      SkeletonLine.body(width: 110),
                    ],
                  ),
                  SizedBox(height: 6),
                  SkeletonLine.caption(width: 160),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
