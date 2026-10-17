import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/bean/widget/tv_focus.dart';
import 'package:kazumi/bean/widget/tv_nav_rail.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/router.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key, required this.location});

  final String location;

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  final _railKey = GlobalKey<TvNavRailState>();
  final FocusScopeNode _contentScope = FocusScopeNode(debugLabel: 'menu-content');
  late int _selectedIndex = menu.indexForPath(widget.location);
  DateTime? _lastExitPromptAt;
  bool _initialRailFocusDone = false;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  bool _isCovered = false;

  @override
  void initState() {
    super.initState();
    // 遥控器没有「鼠标点一下」这个动作，必须主动给一个初始焦点，
    // 否则方向键永远找不到起点，整个界面按什么都没反应。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureInitialRailFocus();
      }
    });
  }

  /// 首帧可能还判定不出横竖屏（拿到尺寸前按竖屏走），
  /// 所以每次横屏构建都补一次，直到焦点真的落进界面为止。
  void _ensureInitialRailFocus() {
    if (!tvDpadEnabled || _initialRailFocusDone) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialRailFocusDone) {
        return;
      }
      final FocusNode? primary = FocusManager.instance.primaryFocus;
      final FocusScopeNode root = FocusManager.instance.rootScope;
      if (primary != null && !identical(primary, root)) {
        _initialRailFocusDone = true;
        return;
      }
      final TvNavRailState? rail = _railKey.currentState;
      if (rail != null) {
        _initialRailFocusDone = true;
        rail.focusSelected();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScaffoldMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _selectedIndex = menu.indexForPath(widget.location);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      rootRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    _contentScope.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _setCovered(true);
    _restoreFocusAfterRouteChange();
  }

  @override
  void didPopNext() {
    _setCovered(false);
    // 从详情页返回时回到刚才停留的位置，而不是从头开始。
    _restoreFocusAfterRouteChange(preferContent: true);
  }

  /// 路由切换后（进详情页、返回主页）把焦点落到新页面里。
  ///
  /// 遥控器不像鼠标，页面换掉以后不会自己产生焦点；不补这一步，
  /// 新页面按什么键都没有反应。
  void _restoreFocusAfterRouteChange({bool preferContent = false}) {
    if (!tvDpadEnabled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final FocusNode? primary = FocusManager.instance.primaryFocus;
      final FocusScopeNode root = FocusManager.instance.rootScope;
      if (primary != null && !identical(primary, root)) {
        return;
      }
      if (preferContent) {
        _focusContent();
        return;
      }
      root.nextFocus();
    });
  }

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    if (index == _selectedIndex) {
      return;
    }
    final outlet = _outletKey.currentState;
    if (outlet == null) return;
    outlet.navigate('/tab${menu.getPath(index)}/');
    setState(() => _selectedIndex = index);
    // 切换 tab 后内容区整棵子树重建，焦点会丢到根上；
    // 立刻把它按回侧边栏，遥控器才能继续上下选。
    if (tvDpadEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _railKey.currentState?.focusSelected();
        }
      });
    }
  }

  /// 内容区按下左右键：先走 Flutter 内建的方向遍历，
  /// 只有在边界上真的走不动时才把焦点交给侧边栏。
  void _handleContentDirectional(
      BuildContext context, TvDirectionalIntent intent) {
    final FocusNode? before = FocusManager.instance.primaryFocus;
    Actions.invoke(context, DirectionalFocusIntent(intent.direction));
    final FocusNode? after = FocusManager.instance.primaryFocus;
    if (!identical(before, after)) {
      return;
    }
    if (intent.direction == TraversalDirection.left) {
      _railKey.currentState?.focusSelected();
    }
  }

  /// 侧边栏按下右键：把焦点还给内容区上次聚焦的位置。
  void _focusContent() {
    if (_contentScope.hasFocus) {
      return;
    }
    if (_contentScope.focusedChild != null) {
      _contentScope.requestFocus();
      return;
    }
    _contentScope.requestFocus();
    // 内容区还没被聚焦过时，scope 自身拿到焦点，
    // 需要再推一把，把焦点送到第一个可聚焦元素（第一张卡片）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_contentScope.hasFocus) {
        return;
      }
      if (_contentScope.focusedChild == null) {
        _contentScope.nextFocus();
      }
    });
  }

  void _handleSystemBack(BuildContext context) {
    // 浮层菜单开着时，返回键先关菜单，而不是弹退出提示。
    if (KazumiOpenMenus.hasOpen) {
      KazumiOpenMenus.closeAll();
      _lastExitPromptAt = null;
      return;
    }
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    if (_selectedIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return RouteVisibility(
      isCovered: _isCovered,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleSystemBack(context);
          }
        },
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              _ensureInitialRailFocus();
            }
            return orientation == Orientation.portrait
                ? _bottomMenu(context, _selectedIndex)
                : _sideMenu(context, _selectedIndex);
          },
        ),
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      // A non-poppable outlet must not override the shell's PopScope state.
      onNotification: (notification) => !notification.canHandlePop,
      child: RouterOutlet(key: _outletKey),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _bottomMenu(BuildContext context, int selectedIndex) {
    return Scaffold(
      body: _outlet(context),
      bottomNavigationBar: NavigationBar(
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: '推荐',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.timeline),
            icon: Icon(Icons.timeline_outlined),
            label: '时间表',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.favorite),
            icon: Icon(Icons.favorite_outlined),
            label: '追番',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }

  Widget _sideMenu(BuildContext context, int selectedIndex) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: TvNavRail(
              key: _railKey,
              selectedIndex: selectedIndex,
              destinations: const <TvNavDestination>[
                TvNavDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: '推荐',
                ),
                TvNavDestination(
                  icon: Icons.timeline_outlined,
                  selectedIcon: Icons.timeline,
                  label: '时间表',
                ),
                TvNavDestination(
                  icon: Icons.favorite_border,
                  selectedIcon: Icons.favorite,
                  label: '追番',
                ),
                TvNavDestination(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: '我的',
                ),
              ],
              onSelected: _selectDestination,
              onEscapeRight: _focusContent,
              leading: const TvNavDestination(
                icon: Icons.search,
                selectedIcon: Icons.search,
                label: '搜索',
              ),
              onLeadingActivated: () => context.pushNamed('/search/'),
            ),
          ),
          Expanded(
            child: FocusScope(
              node: _contentScope,
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowLeft):
                      TvDirectionalIntent(TraversalDirection.left),
                  SingleActivator(LogicalKeyboardKey.arrowRight):
                      TvDirectionalIntent(TraversalDirection.right),
                },
                child: Builder(
                  builder: (innerContext) => Actions(
                    actions: <Type, Action<Intent>>{
                      TvDirectionalIntent: CallbackAction<TvDirectionalIntent>(
                        onInvoke: (TvDirectionalIntent intent) =>
                            _handleContentDirectional(innerContext, intent),
                      ),
                    },
                    child: _outlet(context, borderRadius: borderRadius),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
