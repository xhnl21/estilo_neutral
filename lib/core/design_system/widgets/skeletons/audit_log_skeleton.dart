import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la vista de registro de auditoría en [AuditLogPage].
class AuditLogSkeleton extends StatelessWidget {
  final int itemCount;

  const AuditLogSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          // Selector horizontal de hojas
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              children: const [
                SkeletonBox(width: 70, height: 32),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(width: 80, height: 32),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(width: 90, height: 32),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(width: 75, height: 32),
              ],
            ),
          ),

          // Lista de logs
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
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
                            SkeletonLine.subtitle(width: 130),
                            SkeletonBox(width: 80, height: 20),
                          ],
                        ),
                        SizedBox(height: 8),
                        SkeletonBox(
                          width: double.infinity,
                          height: 36,
                          borderRadius: AppSpacing.roundedSm,
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonLine.caption(width: 140),
                            SkeletonBox(width: 90, height: 20),
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
