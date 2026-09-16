import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para Tesorería en [TreasuryPage].
class TreasurySkeleton extends StatelessWidget {
  final int itemCount;

  const TreasurySkeleton({
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
                    SkeletonLine.caption(width: 140),
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
                        SkeletonLine.caption(width: 90),
                        SizedBox(height: 6),
                        SkeletonLine.title(width: 110),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SkeletonLine.caption(width: 90),
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

          const SkeletonLine.subtitle(width: 180),
          const SizedBox(height: AppSpacing.sm),

          // Compras list
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
                        Row(
                          children: [
                            SkeletonLine.subtitle(width: 100),
                            SizedBox(width: AppSpacing.xs),
                            SkeletonBox(width: 50, height: 18),
                          ],
                        ),
                        SkeletonLine.title(width: 80),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonLine.body(width: 130),
                        SkeletonLine.caption(width: 70),
                      ],
                    ),
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
