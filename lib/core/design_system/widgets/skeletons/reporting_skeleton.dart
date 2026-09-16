import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de reportes y cierres en [ReportingPage].
class ReportingSkeleton extends StatelessWidget {
  final int itemCount;

  const ReportingSkeleton({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          80,
        ),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Consolidado Card
          const SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLine.caption(width: 170),
                    SkeletonBox(width: 18, height: 18),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine.caption(width: 100),
                        SizedBox(height: 6),
                        SkeletonLine.title(width: 110),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SkeletonLine.caption(width: 100),
                        SizedBox(height: 6),
                        SkeletonLine.title(width: 110),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SkeletonLine.subtitle(width: 160),
          const SizedBox(height: AppSpacing.sm),

          // Cierres Diarios
          ...List.generate(itemCount, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonLine.subtitle(width: 120),
                        SkeletonLine.title(width: 90),
                      ],
                    ),
                    SizedBox(height: 6),
                    SkeletonLine.body(width: 190),
                    SizedBox(height: 6),
                    SkeletonLine.caption(width: double.infinity),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
