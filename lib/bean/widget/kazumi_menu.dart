import 'package:flutter/material.dart';

typedef KazumiMenuBuilder =
    Widget Function(BuildContext context, VoidCallback? toggle);

/// 当前处于打开状态的浮层菜单。
///
/// 遥控器按返回键时先关菜单，而不是弹「再按一次退出应用」。
class KazumiOpenMenus {
  KazumiOpenMenus._();

  static final Set<MenuController> _controllers = <MenuController>{};

  static bool get hasOpen => _controllers.isNotEmpty;

  static void add(MenuController controller) => _controllers.add(controller);

  static void remove(MenuController controller) =>
      _controllers.remove(controller);

  static void closeAll() {
    for (final MenuController controller in _controllers.toList()) {
      controller.close();
    }
    _controllers.clear();
  }
}

const _menuItemStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(144, 48)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
  alignment: AlignmentDirectional.centerStart,
  visualDensity: VisualDensity.standard,
);

class KazumiMenuButton extends StatefulWidget {
  const KazumiMenuButton({
    super.key,
    required this.builder,
    required this.menuChildren,
    this.controller,
    this.enabled = true,
    this.animated = false,
    this.crossAxisUnconstrained = true,
    this.onOpen,
    this.onClose,
    this.style,
  });

  final KazumiMenuBuilder builder;
  final List<Widget> menuChildren;
  final MenuController? controller;
  final bool enabled;

  /// Opt in only for menus that previously animated.
  final bool animated;
  final bool crossAxisUnconstrained;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final MenuStyle? style;

  @override
  State<KazumiMenuButton> createState() => _KazumiMenuButtonState();
}

class _KazumiMenuButtonState extends State<KazumiMenuButton> {
  MenuController? _ownController;

  MenuController get _controller =>
      widget.controller ?? (_ownController ??= MenuController());

  @override
  void dispose() {
    KazumiOpenMenus.remove(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuButtonTheme(
      data: MenuButtonThemeData(
        // Submenu entries must use the same inset as ordinary menu items.
        style: _menuItemStyle.merge(MenuButtonTheme.of(context).style),
      ),
      child: MenuAnchor(
        controller: _controller,
        consumeOutsideTap: true,
        crossAxisUnconstrained: widget.crossAxisUnconstrained,
        animated:
            widget.animated && !MediaQuery.disableAnimationsOf(context),
        onOpen: () {
          KazumiOpenMenus.add(_controller);
          widget.onOpen?.call();
        },
        onClose: () {
          KazumiOpenMenus.remove(_controller);
          widget.onClose?.call();
        },
        style: widget.style,
        menuChildren: widget.menuChildren,
        builder: (context, controller, _) => widget.builder(
          context,
          widget.enabled && widget.menuChildren.isNotEmpty
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
        ),
      ),
    );
  }
}

class KazumiMenuItem extends StatelessWidget {
  const KazumiMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.selected,
    this.destructive = false,
    this.requestFocusOnHover = true,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;

  /// Null for actions; a bool exposes single-choice selection semantics.
  final bool? selected;
  final bool destructive;
  final bool requestFocusOnHover;

  /// 遥控器展开菜单后把焦点直接落在这一项上。
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive
        ? colors.error
        : selected == true
        ? colors.primary
        : null;
    final foregroundColor = color == null
        ? null
        : WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled) ? null : color,
          );
    return MenuItemButton(
      onPressed: onPressed,
      autofocus: autofocus,
      requestFocusOnHover: requestFocusOnHover,
      style: ButtonStyle(
        foregroundColor: foregroundColor,
        iconColor: foregroundColor,
      ),
      leadingIcon: leadingIcon,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: selected == null ? null : true,
        child: Text(label, textAlign: TextAlign.start),
      ),
    );
  }
}
