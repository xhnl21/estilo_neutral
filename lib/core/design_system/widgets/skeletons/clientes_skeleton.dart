import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_circle.dart';
import 'skeleton_line.dart';

/// Skeleton loader para la lista de clientes en [ClientesPage].
class ClientesListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const ClientesListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      80,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: padding,
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SkeletonCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonCircle(radius: 20),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine.title(width: 140),
                        SizedBox(height: 6),
                        SkeletonLine.body(width: 180),
                        SizedBox(height: 6),
                        SkeletonBox(
                          width: 65,
                          height: 18,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SkeletonLine.caption(width: 40),
                      SizedBox(height: 4),
                      SkeletonLine.subtitle(width: 70),
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
