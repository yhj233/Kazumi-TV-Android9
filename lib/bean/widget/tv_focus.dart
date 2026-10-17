import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 遥控器（D-pad）焦点增强是否启用。
///
/// 只在 Android 上启用：电视盒子、投影、以及外接遥控/手柄的场景都走这套。
/// 桌面端自身有鼠标键盘焦点体系，移动端竖屏仍以触摸为主，都不受影响。
final bool tvDpadEnabled =
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// 遥控器「确定键」和手柄 A 键到 [ActivateIntent] 的映射。
///
/// Android 的 KEYCODE_DPAD_CENTER 在 Flutter 里是 [LogicalKeyboardKey.select]，
/// 它不在 Flutter 默认快捷键表里——这正是遥控器按确定没反应的原因之一。
const Map<ShortcutActivator, Intent> tvActivateShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
};

/// 在内容区里按下左右键的意图，由主菜单容器（ScaffoldMenu）处理。
///
/// 先交给 Flutter 内建的方向遍历；只有当遍历真的走不动（已经在最左/最右列）
/// 时才做跨区域跳转。
class TvDirectionalIntent extends Intent {
  const TvDirectionalIntent(this.direction);

  final TraversalDirection direction;
}

/// 从侧边栏右侧逃逸回内容区。
class TvEscapeRailIntent extends Intent {
  const TvEscapeRailIntent();
}

/// 带可见焦点环的可聚焦组件。
///
/// 触屏行为完全不变：点击仍然走 child 自己的手势识别，这里只负责
/// 「焦点可见 + 确定键激活 + 轻微放大」三件事。
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    required this.onActivate,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.scale = 1.0,
    this.enabled = true,
    this.onFocusChange,
    this.focusBorderColor,
  });

  final Widget child;

  /// 按下确定键（或手柄 A / 回车）时触发。
  final VoidCallback onActivate;

  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius borderRadius;

  /// 获得焦点时的放大倍数，1.0 表示不放大。
  final double scale;

  final bool enabled;
  final ValueChanged<bool>? onFocusChange;

  /// 焦点描边颜色，为空时使用主题主色。
  final Color? focusBorderColor;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _node;
  bool _ownsNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
    _ownsNode = widget.focusNode == null;
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsNode) {
        _node.dispose();
      }
      _node = widget.focusNode ?? FocusNode();
      _ownsNode = widget.focusNode == null;
    }
  }

  @override
  void dispose() {
    if (_ownsNode) {
      _node.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (focused) {
      _ensureVisible();
    }
  }

  /// 焦点移到列表/网格之外的元素时把内容滚进来。
  ///
  /// 侧边栏这类不在 Scrollable 里的位置直接跳过。
  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_node.hasFocus) {
        return;
      }
      if (Scrollable.maybeOf(context) == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        widget.focusBorderColor ?? Theme.of(context).colorScheme.primary;
    final bool highlighted = _focused;

    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      mouseCursor: SystemMouseCursors.click,
      shortcuts: tvActivateShortcuts,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate();
            return null;
          },
        ),
      },
      onFocusChange: _handleFocusChange,
      child: AnimatedScale(
        scale: _focused ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          children: <Widget>[
            widget.child,
            // 用叠加层画描边，避免 focus 前后布局发生位移。
            if (highlighted)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: borderColor, width: 4),
                      // 电视观看距离远，单靠描边不够，再补一圈外发光。
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
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
