import "package:flutter/material.dart";
import "package:shimmer/shimmer.dart";
import "../../theme.dart";

/// A Neumorphic Shimmer container that smoothly sweeps across the soft canvas
class NeumorphicShimmer extends StatelessWidget {
  final Widget child;

  const NeumorphicShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: HermesTokens.bgTertiary,
      highlightColor: HermesTokens.bgHover,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Generic rounded placeholder box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HermesTokens.bgTertiary,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 1. Skeletons for Chat Sessions list (chat_screen.dart)
class SessionListSkeleton extends StatelessWidget {
  final int count;
  const SessionListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return NeumorphicShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: NeumorphicDecoration.raised(radius: 16, distance: 2.5, blur: 5),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: HermesTokens.bgTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14, radius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 11, radius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SkeletonBox(width: 32, height: 10, radius: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2. Skeletons for Capabilities & Tools Cards (Skills, Toolsets, MCP)
class CapabilityListSkeleton extends StatelessWidget {
  final int count;
  const CapabilityListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return NeumorphicShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: NeumorphicDecoration.raised(radius: 16, distance: 2.5, blur: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: HermesTokens.bgTertiary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 13, radius: 4),
                        SizedBox(height: 6),
                        SkeletonBox(width: 70, height: 10, radius: 3),
                      ],
                    ),
                  ),
                  const SkeletonBox(width: 24, height: 24, radius: 6),
                ],
              ),
              const SizedBox(height: 14),
              const SkeletonBox(width: double.infinity, height: 10, radius: 3),
              const SizedBox(height: 6),
              const SkeletonBox(width: 200, height: 10, radius: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3. Skeletons for Kanban Board (kanban_screen.dart)
class KanbanBoardSkeleton extends StatelessWidget {
  const KanbanBoardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: SkeletonBox(width: 80, height: 12, radius: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: SkeletonBox(width: 80, height: 12, radius: 4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (_, index) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: NeumorphicDecoration.raised(radius: 16, distance: 2.5, blur: 5),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonBox(width: 150, height: 14, radius: 4),
                          SkeletonBox(width: 44, height: 14, radius: 6),
                        ],
                      ),
                      SizedBox(height: 10),
                      SkeletonBox(width: double.infinity, height: 10, radius: 3),
                      SizedBox(height: 6),
                      SkeletonBox(width: 180, height: 10, radius: 3),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          SkeletonBox(width: 60, height: 18, radius: 6),
                          SizedBox(width: 8),
                          SkeletonBox(width: 50, height: 18, radius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. Skeletons for Achievements (achievements_screen.dart)
class AchievementListSkeleton extends StatelessWidget {
  const AchievementListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: NeumorphicDecoration.raised(radius: 16, distance: 2.5, blur: 5),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HermesTokens.bgTertiary,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 130, height: 13, radius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 190, height: 10, radius: 3),
                    SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 6, radius: 3),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SkeletonBox(width: 36, height: 14, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// 5. Skeleton for Model List (model_config_screen.dart)
class ModelListSkeleton extends StatelessWidget {
  final int count;
  const ModelListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return NeumorphicShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, index) => Divider(height: 1, color: HermesTokens.divider),
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 13, radius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 70, height: 10, radius: 3),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: HermesTokens.bgTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
