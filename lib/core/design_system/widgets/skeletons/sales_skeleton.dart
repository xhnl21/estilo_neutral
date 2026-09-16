import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de ventas en [SalesPage].
class SalesSkeleton extends StatelessWidget {
  final int itemCount;
  final bool includeHeaderMetrics;

  const SalesSkeleton({
    super.key,
    this.itemCount = 5,
    this.includeHeaderMetrics = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          if (includeHeaderMetrics) ...[
            // KPI cards
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SkeletonCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine.caption(width: 100),
                          SizedBox(height: 8),
                          SkeletonLine.title(width: 80),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SkeletonCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine.caption(width: 100),
                          SizedBox(height: 8),
                          SkeletonLine.title(width: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chips
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  SkeletonBox(width: 60, height: 32),
                  SizedBox(width: AppSpacing.sm),
                  SkeletonBox(width: 70, height: 32),
                  SizedBox(width: AppSpacing.sm),
                  SkeletonBox(width: 75, height: 32),
                ],
              ),
            ),
          ],

          // Lista de ventas
          Expanded(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonLine.subtitle(width: 90),
                            SkeletonBox(width: 65, height: 20),
                          ],
                        ),
                        SizedBox(height: 8),
                        SkeletonLine.title(width: 160),
                        SizedBox(height: 6),
                        SkeletonLine.caption(width: 120),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonLine.body(width: 80),
                            SkeletonLine.body(width: 90),
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
  }
}
