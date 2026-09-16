import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de cuarentena en [CuarentenaPage].
class CuarentenaSkeleton extends StatelessWidget {
  final int itemCount;

  const CuarentenaSkeleton({
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
                    children: [
                      SkeletonLine.subtitle(width: 140),
                      SizedBox(width: AppSpacing.xs),
                      SkeletonBox(width: 70, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonLine.body(width: 200),
                  SizedBox(height: 8),
                  SkeletonBox(
                    width: double.infinity,
                    height: 38,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SkeletonBox(width: 70, height: 24),
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
