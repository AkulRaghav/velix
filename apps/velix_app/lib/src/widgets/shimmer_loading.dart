import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerLoading({super.key, this.width = double.infinity, required this.height, this.radius = 8});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(baseColor: Colors.white.withValues(alpha: 0.05), highlightColor: Colors.white.withValues(alpha: 0.1), child: Container(width: width, height: height, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius))));
}
