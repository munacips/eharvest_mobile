import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/my_account_page.dart';
import 'package:eharvest_mobile/pages/buy_page.dart';
import 'package:eharvest_mobile/pages/sell_page.dart';
import 'package:eharvest_mobile/pages/logistics_page.dart';
import 'package:eharvest_mobile/pages/ai_forecast_page.dart';
import 'package:eharvest_mobile/pages/demand_supply_forecast_page.dart';
import 'package:eharvest_mobile/pages/season_recommendations_page.dart';
import 'package:eharvest_mobile/pages/supply_map_screen.dart';
import 'package:eharvest_mobile/pages/subscriptions_page.dart';
import 'package:eharvest_mobile/pages/chat_inbox_page.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/review_service.dart';
import 'package:eharvest_mobile/utils/responsive_breakpoints.dart';
import 'package:eharvest_mobile/widgets/count_badge.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TabContainer extends StatefulWidget {
  const TabContainer({super.key});

  @override
  State<TabContainer> createState() => _TabContainerState();
}

class _TabContainerState extends State<TabContainer> {
  int _currentIndex = 0;
  String _roleKey = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refreshPendingReviewCount();
  }

  String _normalizeRoleKey(String rawRole) {
    final normalized = rawRole.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final baseRole = normalized.startsWith('role_')
        ? normalized.substring('role_'.length)
        : normalized;

    switch (baseRole) {
      case 'farmer':
      case 'buyer':
        return baseRole;
      case 'logistics':
      case 'logistics_provider':
      case 'logisticsprovider':
      case 'driver':
        return 'logistics';
      default:
        return baseRole;
    }
  }

  Future<void> _loadRole() async {
    final role = await AuthService.getRole();
    if (!mounted) {
      return;
    }
    setState(() {
      _roleKey = _normalizeRoleKey(role ?? '');
      _currentIndex = 0;
    });
  }

  Future<void> _refreshPendingReviewCount() async {
    try {
      await ReviewService.refreshPendingReviewCount();
    } catch (_) {}
  }

  bool get _canAccessBuy => _roleKey == 'buyer';
  bool get _canAccessSell => _roleKey == 'farmer';

  List<({Widget page, Widget icon, String label})> _visibleTabs() {
    return <({Widget page, Widget icon, String label})>[
      (
        page: const HomePage(),
        icon: const Icon(Icons.home),
        label: 'Home',
      ),
      if (_canAccessBuy)
        (
          page: const BuyPage(),
          icon: const Icon(Icons.money),
          label: 'Buy',
        ),
      if (_canAccessSell)
        (
          page: const SellPage(),
          icon: const Icon(Icons.sell),
          label: 'Sell',
        ),
      (
        page: const LogisticsPage(),
        icon: const Icon(Icons.local_shipping),
        label: 'Logistics',
      ),
      (
        page: const ChatInboxPage(),
        icon: const Icon(Icons.chat_bubble_outline),
        label: 'Chat',
      ),
      (
        page: const MyAccountPage(),
        icon: ValueListenableBuilder<int>(
          valueListenable: ReviewService.pendingReviewCount,
          builder: (context, count, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.account_circle),
                if (count > 0)
                  const Positioned(
                    top: -6,
                    right: -12,
                    child: _MyAccountBadge(),
                  ),
              ],
            );
          },
        ),
        label: 'My Account',
      ),
    ];
  }

  // Build the selected page on-demand so it is recreated each time
  // the tab is opened. This avoids keeping pages alive in memory
  // (as IndexedStack does) and forces a fresh load on each selection.
  Widget _buildCurrentPage() {
    final tabs = _visibleTabs();
    final index = _currentIndex.clamp(0, tabs.length - 1);
    return tabs[index].page;
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error during logout')));
      }
    }
  }

  void _openAiForecasts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiForecastPage()),
    );
  }

  void _openDemandSupply() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DemandSupplyForecastPage()),
    );
  }

  void _openRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SeasonRecommendationsPage()),
    );
  }

  void _openSupplyHeatmap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupplyMapScreen()),
    );
  }

  void _openSubscriptions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionsPage()),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(primaryColour)),
            child: Text(
              'eHarvest Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          const ListTile(leading: Icon(Icons.home), title: Text('Home')),
          ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Forecasts'),
            onTap: () {
              Navigator.pop(context);
              _openAiForecasts();
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.price_check),
          //   title: const Text('Bulk Pricing'),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const BulkPricingPage()),
          //     );
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.timeline),
            title: const Text('Demand & Supply'),
            onTap: () {
              Navigator.pop(context);
              _openDemandSupply();
            },
          ),
          ListTile(
            leading: const Icon(Icons.agriculture),
            title: const Text('Recommendations'),
            onTap: () {
              Navigator.pop(context);
              _openRecommendations();
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Supply Heatmap'),
            onTap: () {
              Navigator.pop(context);
              _openSupplyHeatmap();
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Subscriptions'),
            onTap: () {
              Navigator.pop(context);
              _openSubscriptions();
            },
          ),
          const ListTile(leading: Icon(Icons.settings), title: Text('Settings')),
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActions() {
    return PopupMenuButton<_DesktopMenuAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _DesktopMenuAction.forecasts:
            _openAiForecasts();
            break;
          case _DesktopMenuAction.demandSupply:
            _openDemandSupply();
            break;
          case _DesktopMenuAction.recommendations:
            _openRecommendations();
            break;
          case _DesktopMenuAction.supplyHeatmap:
            _openSupplyHeatmap();
            break;
          case _DesktopMenuAction.subscriptions:
            _openSubscriptions();
            break;
          case _DesktopMenuAction.logout:
            _logout();
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_DesktopMenuAction>>[
        const PopupMenuItem<_DesktopMenuAction>(
          value: _DesktopMenuAction.forecasts,
          child: ListTile(
            leading: Icon(Icons.insights),
            title: Text('Forecasts'),
          ),
        ),
        const PopupMenuItem<_DesktopMenuAction>(
          value: _DesktopMenuAction.demandSupply,
          child: ListTile(
            leading: Icon(Icons.timeline),
            title: Text('Demand & Supply'),
          ),
        ),
        const PopupMenuItem<_DesktopMenuAction>(
          value: _DesktopMenuAction.recommendations,
          child: ListTile(
            leading: Icon(Icons.agriculture),
            title: Text('Recommendations'),
          ),
        ),
        const PopupMenuItem<_DesktopMenuAction>(
          value: _DesktopMenuAction.supplyHeatmap,
          child: ListTile(
            leading: Icon(Icons.map),
            title: Text('Supply Heatmap'),
          ),
        ),
        const PopupMenuItem<_DesktopMenuAction>(
          value: _DesktopMenuAction.subscriptions,
          child: ListTile(
            leading: Icon(Icons.repeat),
            title: Text('Subscriptions'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_DesktopMenuAction>(
          value: _DesktopMenuAction.logout,
          child: ListTile(leading: Icon(Icons.logout), title: Text('Logout')),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(
    List<({Widget page, Widget icon, String label})> tabs,
    int index,
  ) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        _refreshPendingReviewCount();
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color(primaryColour),
      unselectedItemColor: Colors.grey,
      items: tabs
          .map(
            (tab) => BottomNavigationBarItem(
              icon: tab.icon,
              label: tab.label,
            ),
          )
          .toList(),
    );
  }

  Widget _buildNavigationRail(
    List<({Widget page, Widget icon, String label})> tabs,
    int index,
    double width,
  ) {
    final extended = width >= ResponsiveBreakpoints.wideDesktop;

    return NavigationRail(
      extended: extended,
      minExtendedWidth: 180,
      selectedIndex: index,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
        _refreshPendingReviewCount();
      },
      backgroundColor: Colors.white,
      selectedIconTheme: IconThemeData(color: Color(primaryColour)),
      selectedLabelTextStyle: TextStyle(
        color: Color(primaryColour),
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: const IconThemeData(color: Colors.grey),
      labelType: extended ? null : NavigationRailLabelType.all,
      destinations: tabs
          .map(
            (tab) => NavigationRailDestination(
              icon: tab.icon,
              label: Text(tab.label),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = ResponsiveBreakpoints.isDesktopWidth(
          constraints.maxWidth,
        );
        final tabs = _visibleTabs();
        final index = _currentIndex.clamp(0, tabs.length - 1);

        return Scaffold(
          appBar: AppBar(
            title: const Text('eHarverst'),
            backgroundColor: Color(primaryColour),
            actions: isDesktop ? [_buildDesktopActions()] : null,
          ),
          drawer: isDesktop ? null : _buildDrawer(),
          body: isDesktop
              ? Row(
                  children: [
                    _buildNavigationRail(tabs, index, constraints.maxWidth),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _buildCurrentPage()),
                  ],
                )
              : _buildCurrentPage(),
          bottomNavigationBar: isDesktop
              ? null
              : _buildBottomNavigationBar(tabs, index),
        );
      },
    );
  }
}

enum _DesktopMenuAction {
  forecasts,
  demandSupply,
  recommendations,
  supplyHeatmap,
  subscriptions,
  logout,
}

class _MyAccountBadge extends StatelessWidget {
  const _MyAccountBadge();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ReviewService.pendingReviewCount,
      builder: (context, count, _) => CountBadge(count: count),
    );
  }
}
