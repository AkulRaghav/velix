import 'package:flutter/material.dart';
class AvatarGroup extends StatelessWidget {
  final List<String> names;
  final int maxShow;
  const AvatarGroup({super.key, required this.names, this.maxShow = 3});
  @override
  Widget build(BuildContext context) {
    final show = names.take(maxShow).toList();
    return SizedBox(height: 32, child: Stack(children: [for (var i = 0; i < show.length; i++) Positioned(left: i * 20.0, child: CircleAvatar(radius: 16, backgroundColor: Colors.primaries[i % Colors.primaries.length], child: Text(show[i][0], style: const TextStyle(fontSize: 12, color: Colors.white))))]));
  }
}
