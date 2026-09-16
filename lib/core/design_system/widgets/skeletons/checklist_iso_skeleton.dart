import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de checklist ISO en [ChecklistIsoPage].
class ChecklistIsoSkeleton extends StatelessWidget {
  final int itemCount;

  const ChecklistIsoSkeleton({
    super.key,
    this.itemCount = 5,
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
          // Progreso Global Card
          const SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLine.caption(width: 170),
                    SkeletonLine.subtitle(width: 90),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(
                  width: double.infinity,
                  height: 8,
                  borderRadius: AppSpacing.roundedSm,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Requisitos
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
                        SkeletonLine.subtitle(width: 160),
                        SkeletonBox(width: 75, height: 20),
                      ],
                    ),
                    SizedBox(height: 8),
                    SkeletonLine.body(width: 220),
                    SizedBox(height: 6),
                    SkeletonLine.caption(width: 130),
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
