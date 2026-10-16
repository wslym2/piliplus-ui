import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const double _kMaxLabelTextScaleFactor = 1.3;
const double _kLiquidNavHeight = 64.0;
const double _kLiquidItemWidth = 86.0;
const double _kIndicatorPadding = 4.0;
const double _kIndicatorHeight = _kLiquidNavHeight - 2 * _kIndicatorPadding;
const double _kIndicatorWidth = _kLiquidItemWidth - 2 * _kIndicatorPadding;
const BorderRadius _kLiquidBorderRadius = BorderRadius.all(Radius.circular(_kLiquidNavHeight / 2));

/// 液态玻璃悬浮底栏组件 (Liquid Glass Floating Navigation Bar)
/// 专为 PiliPlus 深度定制，融合 iOS 26/27 拟物液态毛玻璃质感、物理弹簧阻尼滑动滑块与按压回弹微动效。
class LiquidGlassNavigationBar extends StatefulWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.destinations,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.animationDuration = const Duration(milliseconds: 380),
    this.bottomPadding = 8.0,
  }) : assert(destinations.length >= 2),
       assert(0 <= selectedIndex && selectedIndex < destinations.length);

  final List<LiquidGlassNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Duration animationDuration;
  final double bottomPadding;

  @override
  State<LiquidGlassNavigationBar> createState() => _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar>
    with SingleTickerProviderStateMixin {
  int? _pressedIndex;
  late int _lastIndex;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      setState(() {
        _lastIndex = widget.selectedIndex;
        _isAnimating = true;
      });
      Future.delayed(widget.animationDuration, () {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      });
    }
  }

  void _handleTap(int index) {
    if (!widget.destinations[index].enabled) return;
    HapticFeedback.lightImpact();
    widget.onDestinationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final padding = MediaQuery.viewPaddingOf(context);
    final totalWidth = widget.destinations.length * _kLiquidItemWidth;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          0,
          padding.right,
          widget.bottomPadding + padding.bottom,
        ),
        child: Center(
          child: SizedBox(
            height: _kLiquidNavHeight,
            width: totalWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. 底层环境漫反射高斯阴影 (Ambient Shadow)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: _kLiquidBorderRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: (isDark ? Colors.black : theme.colorScheme.primary)
                              .withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 10,
                          spreadRadius: -2,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. 液态毛玻璃主体容器 (BackdropFilter + 渐变高光边框 + 亚克力半透色)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: _kLiquidBorderRadius,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: CustomPaint(
                        painter: _LiquidGlassBorderPainter(
                          isDark: isDark,
                          primaryColor: theme.colorScheme.primary,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: _kLiquidBorderRadius,
                            color: isDark
                                ? const Color(0xFF16161A).withValues(alpha: 0.68)
                                : Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. 仿 iOS 弹性液态滑块指示器 (Sliding Liquid Pill Indicator)
                AnimatedPositioned(
                  duration: widget.animationDuration,
                  curve: Curves.fastLinearToSlowEaseIn,
                  top: _kIndicatorPadding,
                  bottom: _kIndicatorPadding,
                  left: widget.selectedIndex * _kLiquidItemWidth + _kIndicatorPadding,
                  width: _kIndicatorWidth,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    scale: _pressedIndex == widget.selectedIndex ? 0.94 : 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_kIndicatorHeight / 2),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.92),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.8),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Tab 按钮交互层 (图标、文字、按压阻尼与触觉反馈)
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < widget.destinations.length; i++)
                        Expanded(
                          child: _LiquidTabItem(
                            index: i,
                            isSelected: i == widget.selectedIndex,
                            destination: widget.destinations[i],
                            isPressed: _pressedIndex == i,
                            onTap: () => _handleTap(i),
                            onTapDown: () => setState(() => _pressedIndex = i),
                            onTapUp: () => setState(() => _pressedIndex = null),
                            onTapCancel: () => setState(() => _pressedIndex = null),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 绘制拟物液态玻璃边缘折射高光 (Refractive Edge Glow)
class _LiquidGlassBorderPainter extends CustomPainter {
  const _LiquidGlassBorderPainter({
    required this.isDark,
    required this.primaryColor,
  });

  final bool isDark;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // 绘制顶部高光与底部漫射的双色渐变边框，呈现玻璃折射质感
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        Offset(rect.width / 2, 0),
        Offset(rect.width / 2, rect.height),
        [
          isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.75),
          isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.20),
          isDark
              ? Colors.black.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.10),
        ],
        [0.0, 0.45, 1.0],
      );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassBorderPainter oldDelegate) {
    return isDark != oldDelegate.isDark || primaryColor != oldDelegate.primaryColor;
  }
}

/// 单个 Tab 项微交互动画组件
class _LiquidTabItem extends StatelessWidget {
  const _LiquidTabItem({
    required this.index,
    required this.isSelected,
    required this.destination,
    required this.isPressed,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final int index;
  final bool isSelected;
  final LiquidGlassNavigationDestination destination;
  final bool isPressed;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color selectedColor = theme.colorScheme.primary;
    final Color unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.50);

    final currentColor = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: isPressed ? 0.90 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<bool>(isSelected),
                  child: IconTheme(
                    data: IconThemeData(
                      color: currentColor,
                      size: isSelected ? 23 : 21,
                    ),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: currentColor,
                  letterSpacing: 0.2,
                ),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: _kMaxLabelTextScaleFactor,
                  child: Text(destination.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃导航选项配置
class LiquidGlassNavigationDestination extends StatelessWidget {
  const LiquidGlassNavigationDestination({
    super.key,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.tooltip,
    this.enabled = true,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
