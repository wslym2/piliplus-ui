import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const double _kMaxLabelTextScaleFactor = 1.3;
const double _kLiquidNavHeight = 60.0;
const double _kLiquidItemWidth = 84.0;
const double _kIndicatorPadding = 3.5;
const double _kIndicatorHeight = _kLiquidNavHeight - 2 * _kIndicatorPadding;
const double _kIndicatorWidth = _kLiquidItemWidth - 2 * _kIndicatorPadding;
const BorderRadius _kLiquidBorderRadius = BorderRadius.all(Radius.circular(_kLiquidNavHeight / 2));

/// 真正的苹果 iOS 液态玻璃悬浮底栏组件 (Apple Fluid Liquid Glass Navigation Bar)
/// 具备：
/// 1. 严格贴合底部的紧凑尺寸（杜绝任何居中错位）
/// 2. 水滴流体指示器：支持手指直接拖拽跟随、水滴拉伸变形与松手弹性吸附 (Drag & Liquid Stretch & Snap)
/// 3. 水滴受压扩散挤压动效 (Fluid Squash Press Effect)
/// 4. 拟物菲涅尔边缘虹彩折射 (Fresnel Iridescent Refraction) 与凸面光斑
/// 5. 实时亚克力高斯模糊透过底层滚动内容
class LiquidGlassNavigationBar extends StatefulWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.destinations,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.animationDuration = const Duration(milliseconds: 350),
    this.bottomPadding = 12.0,
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
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _stretchAnimation;

  double _currentIndicatorX = 0.0;
  double _targetIndicatorX = 0.0;
  double _stretchFactor = 0.0; // 拖动或滑动时的横向形变量

  bool _isDragging = false;
  bool _isPressed = false;
  int _pressedIndex = -1;
  double _dragStartX = 0.0;
  double _dragIndicatorStartX = 0.0;
  int _lastSnappedIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndicatorX = widget.selectedIndex * _kLiquidItemWidth;
    _targetIndicatorX = _currentIndicatorX;
    _lastSnappedIndex = widget.selectedIndex;

    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(() {
        setState(() {
          _currentIndicatorX = _slideAnimation.value;
          _stretchFactor = _stretchAnimation.value;
        });
      });

    _slideAnimation = AlwaysStoppedAnimation(_currentIndicatorX);
    _stretchAnimation = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && !_isDragging) {
      _animateToTab(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateToTab(int targetIndex) {
    final double targetX = targetIndex * _kLiquidItemWidth;
    final double distance = (targetX - _currentIndicatorX).abs();
    final double maxDistance = (widget.destinations.length - 1) * _kLiquidItemWidth;
    final double normDist = (distance / (maxDistance == 0 ? 1 : maxDistance)).clamp(0.0, 1.0);

    // 计算流体水滴在滑动过程中的横向拉伸幅度 (Liquid Stretch)
    final double maxStretch = normDist * 16.0;

    _animController.stop();

    _slideAnimation = Tween<double>(
      begin: _currentIndicatorX,
      end: targetX,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const SpringCurve(damping: 18.0, stiffness: 180.0),
    ));

    // 拉伸在运动中段达到峰值，到位时回弹归零
    _stretchAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: maxStretch)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: maxStretch, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_animController);

    _targetIndicatorX = targetX;
    _lastSnappedIndex = targetIndex;
    _animController.forward(from: 0.0);
  }

  // 手指按下水滴
  void _onPanDown(DragDownDetails details) {
    _animController.stop();
    setState(() {
      _isPressed = true;
      _dragStartX = details.localPosition.dx;
      _dragIndicatorStartX = _currentIndicatorX;
    });
    HapticFeedback.lightImpact();
  }

  // 手指拖动水滴流体移动
  void _onPanUpdate(DragUpdateDetails details) {
    final double delta = details.localPosition.dx - _dragStartX;
    final double maxPos = (widget.destinations.length - 1) * _kLiquidItemWidth;

    double newX = _dragIndicatorStartX + delta;
    // 边缘橡胶阻尼 (Rubber Band Effect)
    if (newX < 0) {
      newX = -math.pow(-newX, 0.75).toDouble() * 3.0;
    } else if (newX > maxPos) {
      final over = newX - maxPos;
      newX = maxPos + math.pow(over, 0.75).toDouble() * 3.0;
    }

    final int closestIndex = (newX / _kLiquidItemWidth).round().clamp(0, widget.destinations.length - 1);
    if (closestIndex != _lastSnappedIndex) {
      _lastSnappedIndex = closestIndex;
      HapticFeedback.selectionClick();
    }

    setState(() {
      _isDragging = true;
      _currentIndicatorX = newX;
      // 拖拽时依据移动量产生动态水滴微拉伸
      _stretchFactor = (details.primaryDelta ?? 0.0).abs().clamp(0.0, 10.0);
    });
  }

  // 松手自动吸附到最近 Tab
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isPressed = false;
    });

    final double velocity = details.velocity.pixelsPerSecond.dx;
    int targetIndex = (_currentIndicatorX / _kLiquidItemWidth).round();

    // 结合滑动手势速度矢量判断惯性吸附目标
    if (velocity.abs() > 300) {
      if (velocity > 0) {
        targetIndex = (_currentIndicatorX / _kLiquidItemWidth).floor() + 1;
      } else {
        targetIndex = (_currentIndicatorX / _kLiquidItemWidth).ceil() - 1;
      }
    }

    targetIndex = targetIndex.clamp(0, widget.destinations.length - 1);
    HapticFeedback.mediumImpact();
    widget.onDestinationSelected?.call(targetIndex);
    _animateToTab(targetIndex);
  }

  void _onPanCancel() {
    setState(() {
      _isDragging = false;
      _isPressed = false;
    });
    _animateToTab(widget.selectedIndex);
  }

  void _handleTabTap(int index) {
    if (!widget.destinations[index].enabled) return;
    HapticFeedback.lightImpact();
    widget.onDestinationSelected?.call(index);
    _animateToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final padding = MediaQuery.viewPaddingOf(context);
    final totalWidth = widget.destinations.length * _kLiquidItemWidth;

    // 水滴受按压时的流体形变 (Squash)
    final double pressSquashW = _isPressed ? 6.0 : 0.0;
    final double pressSquashH = _isPressed ? -3.0 : 0.0;
    final double currentPillWidth = (_kIndicatorWidth + _stretchFactor + pressSquashW).clamp(_kIndicatorWidth * 0.8, _kIndicatorWidth * 1.35);
    final double currentPillHeight = _kIndicatorHeight + pressSquashH;

    // 保持水平居中紧凑布局，绝对不使用全屏扩展，确保位置完美贴合底栏
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          0,
          padding.right,
          widget.bottomPadding + padding.bottom,
        ),
        child: SizedBox(
          height: _kLiquidNavHeight,
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. 底层大范围环境光漫反射柔和阴影 (Ambient Shadow)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _kLiquidBorderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.07),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: (isDark ? Colors.black : theme.colorScheme.primary)
                            .withValues(alpha: isDark ? 0.20 : 0.03),
                        blurRadius: 10,
                        spreadRadius: -1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. 底栏主体磨砂玻璃 (BackdropFilter + 边缘折射光泽)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: _kLiquidBorderRadius,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                    child: CustomPaint(
                      painter: _LiquidGlassBaseBorderPainter(
                        isDark: isDark,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: _kLiquidBorderRadius,
                          color: isDark
                              ? const Color(0xFF16161A).withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. 仿苹果拟物液态水滴指示器 (Interactive Fluid Liquid Droplet Lens)
              Positioned(
                top: _kIndicatorPadding - (pressSquashH / 2),
                left: _currentIndicatorX + _kIndicatorPadding - (_stretchFactor + pressSquashW) / 2,
                width: currentPillWidth,
                height: currentPillHeight,
                child: CustomPaint(
                  painter: _LiquidDropletLensPainter(
                    isDark: isDark,
                    isPressed: _isPressed,
                    primaryColor: theme.colorScheme.primary,
                  ),
                ),
              ),

              // 4. Tab 图标和文字与手势交互层 (支持手势拖拽水滴和点击)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: _onPanDown,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
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
                            onTap: () => _handleTabTap(i),
                            onTapDown: () => setState(() => _pressedIndex = i),
                            onTapUp: () => setState(() => _pressedIndex = -1),
                            onTapCancel: () => setState(() => _pressedIndex = -1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 绘制水滴指示器凸透镜核心质感 (Convex Liquid Lens + Fresnel Iridescent Dispersion)
class _LiquidDropletLensPainter extends CustomPainter {
  const _LiquidDropletLensPainter({
    required this.isDark,
    required this.isPressed,
    required this.primaryColor,
  });

  final bool isDark;
  final bool isPressed;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // A. 水滴微弱弥散阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.30 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    // B. 水滴本体水润半透明通透底色 (Liquid Transparency)
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.width / 2, 0),
        Offset(rect.width / 2, rect.height),
        [
          isDark
              ? Colors.white.withValues(alpha: isPressed ? 0.28 : 0.22)
              : Colors.white.withValues(alpha: isPressed ? 0.95 : 0.88),
          isDark
              ? Colors.white.withValues(alpha: isPressed ? 0.16 : 0.12)
              : Colors.white.withValues(alpha: isPressed ? 0.80 : 0.72),
        ],
      );
    canvas.drawRRect(rrect, bodyPaint);

    // C. 拟物菲涅尔边缘虹彩折射 (Fresnel Iridescent Chromatic Dispersion)
    // 关键！参考图1 Kbattery，边缘呈现极微紫青水滴折射微光，呈现厚玻璃液态折射感
    final iridescentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isPressed ? 1.6 : 1.2
      ..shader = ui.Gradient.sweep(
        rect.center,
        [
          const Color(0xFF64B5F6).withValues(alpha: isDark ? 0.45 : 0.35), // 天蓝折射
          const Color(0xFFBA68C8).withValues(alpha: isDark ? 0.50 : 0.40), // 浅紫折射
          const Color(0xFFFFB74D).withValues(alpha: isDark ? 0.40 : 0.30), // 晨曦金折射
          const Color(0xFF64B5F6).withValues(alpha: isDark ? 0.45 : 0.35),
        ],
        [0.0, 0.4, 0.8, 1.0],
      );
    canvas.drawRRect(rrect, iridescentPaint);

    // D. 凸透镜顶部反光弧线 (Convex Specular Highlight Arc)
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = ui.Gradient.linear(
        Offset(rect.width * 0.25, 0),
        Offset(rect.width * 0.75, 0),
        [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: isDark ? 0.75 : 0.95),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
    final highlightPath = Path()
      ..addArc(
        Rect.fromLTWH(rect.left + 8, rect.top + 1, rect.width - 16, 8),
        math.pi * 1.1,
        math.pi * 0.8,
      );
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidDropletLensPainter oldDelegate) {
    return isDark != oldDelegate.isDark || isPressed != oldDelegate.isPressed;
  }
}

/// 底栏外轮廓亚克力厚玻璃折射边框 (Liquid Glass Base Border)
class _LiquidGlassBaseBorderPainter extends CustomPainter {
  const _LiquidGlassBaseBorderPainter({
    required this.isDark,
  });

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = ui.Gradient.linear(
        Offset(rect.width / 2, 0),
        Offset(rect.width / 2, rect.height),
        [
          isDark ? Colors.white.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.75),
          isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.22),
          isDark ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.12),
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassBaseBorderPainter oldDelegate) => isDark != oldDelegate.isDark;
}

/// 自定义 Apple 风格真实弹簧曲线 (Spring Curve Simulation)
class SpringCurve extends Curve {
  const SpringCurve({this.damping = 16.0, this.stiffness = 160.0});

  final double damping;
  final double stiffness;

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      SpringDescription(mass: 1.0, stiffness: stiffness, damping: damping),
      0.0,
      1.0,
      0.0,
    );
    return sim.x(t * 1.0);
  }
}

/// 单个 Tab 内部元素
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

    final Color selectedColor = isDark ? Colors.white : theme.colorScheme.primary;
    final Color unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : Colors.black.withValues(alpha: 0.45);

    final currentColor = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
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
                duration: const Duration(milliseconds: 260),
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
                      size: isSelected ? 22 : 20,
                    ),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: currentColor,
                  letterSpacing: 0.1,
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

/// 导航选项配置
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
