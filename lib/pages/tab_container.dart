import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/my_account_page.dart';
import 'package:eharvest_mobile/pages/buy_page.dart';
import 'package:eharvest_mobile/pages/sell_page.dart';
import 'package:eharvest_mobile/pages/logistics_page.dart';
import 'package:eharvest_mobile/pages/ai_forecast_page.dart';
import 'package:eharvest_mobile/pages/bulk_pricing_page.dart';
import 'package:eharvest_mobile/pages/demand_supply_forecast_page.dart';
import 'package:eharvest_mobile/pages/market_insights_page.dart';
import 'package:eharvest_mobile/pages/season_recommendations_page.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
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

  bool get _canAccessBuy => _roleKey == 'buyer';
  bool get _canAccessSell => _roleKey == 'farmer';

  List<({Widget page, BottomNavigationBarItem item})> _visibleTabs() {
    return <({Widget page, BottomNavigationBarItem item})>[
      (
        page: const HomePage(),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
      ),
      if (_canAccessBuy)
        (
          page: const BuyPage(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.money),
            label: 'Buy',
          ),
        ),
      if (_canAccessSell)
        (
          page: const SellPage(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.sell),
            label: 'Sell',
          ),
        ),
      (
        page: const LogisticsPage(),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping),
          label: 'Logistics',
        ),
      ),
      (
        page: const MyAccountPage(),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.account_circle),
          label: 'My Account',
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eHarverst'),
        backgroundColor: Color(primaryColour),
      ),
      drawer: Drawer(
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiForecastPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.price_check),
              title: const Text('Bulk Pricing'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BulkPricingPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Demand & Supply'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DemandSupplyForecastPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.agriculture),
              title: const Text('Recommendations'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SeasonRecommendationsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Market Insights'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketInsightsPage()),
                );
              },
            ),
            const ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
            ),
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
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: Builder(
        builder: (context) {
          final tabs = _visibleTabs();
          final index = _currentIndex.clamp(0, tabs.length - 1);
          return BottomNavigationBar(
            currentIndex: index,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Color(primaryColour),
            unselectedItemColor: Colors.grey,
            items: tabs.map((tab) => tab.item).toList(),
          );
        },
      ),
    );
  }
}
