import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_motion/velix_motion.dart';

import 'velix_loader.dart';

/// Velix component contract: Button.
/// See `docs/phase-2/09-component-contracts.md`.
enum VelixButtonVariant { primary, secondary, tertiary, destructive }

enum VelixButtonSize { sm, md, lg }

class VelixButton extends StatefulWidget {
  const VelixButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = VelixButtonVariant.primary,
    this.size = VelixButtonSize.md,
    this.leadingIcon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final VelixButtonVariant variant;
  final VelixButtonSize size;
  final IconData? leadingIcon;
  final bool loading;

  @override
  State<VelixButton> createState() => _VelixButtonState();
}

class _VelixButtonState extends State<VelixButton>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1.0);
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null || widget.loading;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _onDown() {
    if (_disabled) return;
    setState(() => _pressed = true);
    _scale.animateTo(
      0.97,
      duration: const Duration(milliseconds: 100),
      curve: Curves.linear,
    );
    VelixHaptics.tap();
  }

  void _onUp() {
    if (_disabled) return;
    setState(() => _pressed = false);
    _scale.animateTo(
      1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final palette = _palette(v, widget.variant, _pressed);
    final dims = _dims(v, widget.size);

    return Semantics(
      button: true,
      enabled: !_disabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onDown(),
        onTapUp: (_) => _onUp(),
        onTapCancel: _onUp,
        onTap: _disabled ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, _) => Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _disabled && !widget.loading ? 0.4 : 1,
              child: Container(
                constraints: BoxConstraints(minHeight: dims.height, minWidth: 48),
                padding: EdgeInsets.symmetric(horizontal: dims.padX),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius: v.radius.mdAll,
                ),
                alignment: Alignment.center,
                child: widget.loading
                    ? VelixLoader.spinner(
                        size: VelixLoaderSize.xs,
                        color: palette.fg,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.leadingIcon != null) ...[
                            Icon(
                              widget.leadingIcon,
                              size: 18,
                              color: palette.fg,
                            ),
                            SizedBox(width: v.space.insetSm),
                          ],
                          Text(
                            widget.label,
                            style: dims.text.copyWith(color: palette.fg),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static _Palette _palette(VelixTheme v, VelixButtonVariant variant, bool pressed) {
    switch (variant) {
      case VelixButtonVariant.primary:
        return _Palette(
          fill: pressed ? v.colors.accent.s20 : v.colors.accent.signature,
          fg: v.colors.text.inverse,
        );
      case VelixButtonVariant.secondary:
        return _Palette(
          fill: pressed ? v.colors.surface.lifted : v.colors.surface.active,
          fg: v.colors.text.primary,
        );
      case VelixButtonVariant.tertiary:
        return _Palette(
          fill: const Color(0x00000000),
          fg: pressed ? v.colors.accent.s20 : v.colors.accent.signature,
        );
      case VelixButtonVariant.destructive:
        return _Palette(
          fill: pressed ? v.colors.semantic.dangerDeep : v.colors.semantic.danger,
          fg: v.colors.text.inverse,
        );
    }
  }

  static _Dims _dims(VelixTheme v, VelixButtonSize size) {
    switch (size) {
      case VelixButtonSize.sm:
        return _Dims(height: 36, padX: 16, text: v.typography.labelM);
      case VelixButtonSize.md:
        return _Dims(height: 48, padX: 20, text: v.typography.labelL);
      case VelixButtonSize.lg:
        return _Dims(height: 56, padX: 24, text: v.typography.labelL);
    }
  }
}

class _Palette {
  const _Palette({required this.fill, required this.fg});
  final Color fill;
  final Color fg;
}

class _Dims {
  const _Dims({required this.height, required this.padX, required this.text});
  final double height;
  final double padX;
  final TextStyle text;
}
