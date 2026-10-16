import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 苹果 iOS 液态玻璃悬浮操作按钮 (Apple Liquid Glass Floating Action Button)
/// 专为评论回复、动态发布等悬浮操作定制：
/// 1. 实时 BackdropFilter 磨砂毛玻璃透光穿透下方滚动内容
/// 2. 拟物水滴外轮廓与七彩/双层菲涅尔高光边缘
/// 3. 手指按下时的流体挤压水滴阻尼反馈 (Fluid Squash & Spring Bounce)
class LiquidGlassFab extends StatefulWidget {
  const LiquidGlassFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 54.0,
    this.heroTag,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final Object? heroTag;

  @override
  State<LiquidGlassFab> createState() => _LiquidGlassFabState();
}

class _LiquidGlassFabState extends State<LiquidGlassFab> {
  bool _isPressed = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(widget.size / 2);

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: _isPressed ? 0.90 : 1.0,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. 底层大范围环境光漫反射阴影
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. 液态玻璃本体容器 (BackdropFilter 模糊底层滚动内容)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: CustomPaint(
                      painter: _LiquidFabBorderPainter(
                        isDark: isDark,
                        isPressed: _isPressed,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          color: isDark
                              ? const Color(0xFF1E1E24).withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. 图标本体
              Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: isDark ? Colors.white : theme.colorScheme.primary,
                    size: 24,
                  ),
                  child: widget.icon,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return RepaintBoundary(child: button);
  }
}

class _LiquidFabBorderPainter extends CustomPainter {
  const _LiquidFabBorderPainter({
    required this.isDark,
    required this.isPressed,
  });

  final bool isDark;
  final bool isPressed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // 绘制七彩菲涅尔边缘微光
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isPressed ? 1.5 : 1.2
      ..shader = ui.Gradient.sweep(
        rect.center,
        [
          const Color(0xFF64B5F6).withValues(alpha: isDark ? 0.40 : 0.35),
          const Color(0xFFBA68C8).withValues(alpha: isDark ? 0.45 : 0.40),
          const Color(0xFFFFB74D).withValues(alpha: isDark ? 0.35 : 0.30),
          const Color(0xFF64B5F6).withValues(alpha: isDark ? 0.40 : 0.35),
        ],
        [0.0, 0.4, 0.8, 1.0],
      );

    canvas.drawRRect(rrect, edgePaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidFabBorderPainter oldDelegate) {
    return isDark != oldDelegate.isDark || isPressed != oldDelegate.isPressed;
  }
}
