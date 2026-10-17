import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_focus.dart';

/// 侧边栏目的地。
class TvNavDestination {
  const TvNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 遥控器友好的侧边栏。
///
/// 与 [NavigationRail] 的区别：
/// - 每一项都是真正可聚焦的节点，能用上下键在条目间移动；
/// - 焦点有明显视觉反馈（底色 + 描边 + 放大），电视上一眼可见；
/// - 按右键会把焦点交还给内容区，不会被困在侧边栏里。
class TvNavRail extends StatefulWidget {
  const TvNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onEscapeRight,
    this.leading,
    this.onLeadingActivated,
    this.width = 96,
  });

  final List<TvNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 按右键离开侧边栏时调用，用于把焦点还给内容区。
  final VoidCallback onEscapeRight;

  final TvNavDestination? leading;
  final VoidCallback? onLeadingActivated;
  final double width;

  @override
  State<TvNavRail> createState() => TvNavRailState();
}

class TvNavRailState extends State<TvNavRail> {
  late List<FocusNode> _nodes;
  late FocusNode _leadingNode;

  @override
  void initState() {
    super.initState();
    _nodes = List<FocusNode>.generate(
      widget.destinations.length,
      (int i) => FocusNode(debugLabel: 'tv-rail-$i'),
    );
    _leadingNode = FocusNode(debugLabel: 'tv-rail-leading');
  }

  @override
  void didUpdateWidget(TvNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destinations.length != _nodes.length) {
      for (final FocusNode node in _nodes) {
        node.dispose();
      }
      _nodes = List<FocusNode>.generate(
        widget.destinations.length,
        (int i) => FocusNode(debugLabel: 'tv-rail-$i'),
      );
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    _leadingNode.dispose();
    super.dispose();
  }

  /// 把焦点放到当前选中的侧边栏条目上。
  void focusSelected() {
    if (!mounted || _nodes.isEmpty) {
      return;
    }
    final int index = widget.selectedIndex.clamp(0, _nodes.length - 1);
    _nodes[index].requestFocus();
  }

  void focusLeading() {
    if (mounted) {
      _leadingNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: widget.width,
      color: scheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: Column(
          children: <Widget>[
            const Spacer(),
            if (widget.leading != null)
              _TvRailEntry(
                node: _leadingNode,
                destination: widget.leading!,
                selected: false,
                autofocus: false,
                onActivate: widget.onLeadingActivated ?? () {},
                onEscapeRight: widget.onEscapeRight,
                width: widget.width,
              ),
            for (int i = 0; i < widget.destinations.length; i++)
              _TvRailEntry(
                key: ValueKey<String>(widget.destinations[i].label),
                node: _nodes[i],
                destination: widget.destinations[i],
                selected: i == widget.selectedIndex,
                autofocus: i == widget.selectedIndex,
                onActivate: () => widget.onSelected(i),
                onEscapeRight: widget.onEscapeRight,
                width: widget.width,
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _TvRailEntry extends StatefulWidget {
  const _TvRailEntry({
    super.key,
    required this.node,
    required this.destination,
    required this.selected,
    required this.autofocus,
    required this.onActivate,
    required this.onEscapeRight,
    required this.width,
  });

  final FocusNode node;
  final TvNavDestination destination;
  final bool selected;
  final bool autofocus;
  final VoidCallback onActivate;
  final VoidCallback onEscapeRight;
  final double width;

  @override
  State<_TvRailEntry> createState() => _TvRailEntryState();
}

class _TvRailEntryState extends State<_TvRailEntry> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color foreground = widget.selected
        ? scheme.onSecondaryContainer
        : (_focused ? scheme.primary : scheme.onSurfaceVariant);
    final Color background = widget.selected
        ? scheme.secondaryContainer
        : (_focused ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent);

    return FocusableActionDetector(
      focusNode: widget.node,
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      shortcuts: <ShortcutActivator, Intent>{
        ...tvActivateShortcuts,
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const TvEscapeRailIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate();
            return null;
          },
        ),
        TvEscapeRailIntent: CallbackAction<TvEscapeRailIntent>(
          onInvoke: (_) {
            widget.onEscapeRight();
            return null;
          },
        ),
      },
      onFocusChange: (bool focused) {
        if (_focused != focused) {
          setState(() => _focused = focused);
        }
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: widget.width - 16,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: _focused
                ? Border.all(color: scheme.primary, width: 3)
                : Border.all(color: Colors.transparent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                widget.selected
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                size: 26,
                color: foreground,
              ),
              const SizedBox(height: 3),
              Text(
                widget.destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
