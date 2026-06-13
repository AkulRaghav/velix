// A minimal preview app demonstrating that the Velix design tokens compose
// into a runnable Flutter shell. This is for Phase 2 verification only;
// the production application lives in `apps/velix_app` (Phase 5).
//
// Run with:
//   flutter run -t packages/velix_design/example/preview_app.dart

import 'package:flutter/material.dart';

import 'package:velix_design/velix_design.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    final theme = VelixTheme.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Velix design preview',
      // toMaterialTheme() now bakes the VelixTheme extension into ThemeData,
      // so context.velix resolves throughout the app.
      theme: theme.toMaterialTheme(),
      home: const _Preview(),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Scaffold(
      backgroundColor: v.colors.surface.substrate,
      body: SafeArea(
        child: Padding(
          padding: v.space.screenInset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: v.space.s9),
              Text('Velix', style: v.typography.displayS),
              SizedBox(height: v.space.s4),
              Text(
                'Design system reference â€” Phase 2.',
                style: v.typography.bodyL.copyWith(color: v.colors.text.secondary),
              ),
              SizedBox(height: v.space.s9),
              _MaterialChip(
                label: 'Tier 1 â€” quiet',
                material: v.materials.quiet,
              ),
              SizedBox(height: v.space.s5),
              _MaterialChip(
                label: 'Tier 2 â€” active',
                material: v.materials.active,
              ),
              SizedBox(height: v.space.s5),
              _MaterialChip(
                label: 'Tier 3 â€” lifted',
                material: v.materials.lifted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialChip extends StatelessWidget {
  const _MaterialChip({required this.label, required this.material});
  final String label;
  final VelixMaterial material;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: material.fill,
        borderRadius: v.radius.lgAll,
        border: material.edge == null
            ? null
            : Border.all(color: material.edge!, width: 1),
        boxShadow: v.shadows.elevation2,
      ),
      padding: v.space.cardPadding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(label, style: v.typography.titleS),
      ),
    );
  }
}
