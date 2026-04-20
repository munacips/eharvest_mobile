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

  // Build the selected page on-demand so it is recreated each time
  // the tab is opened. This avoids keeping pages alive in memory
  // (as IndexedStack does) and forces a fresh load on each selection.
  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomePage();
      case 1:
        return BuyPage();
      case 2:
        return SellPage();
      case 3:
        return LogisticsPage();
      case 4:
        return MyAccountPage();
      default:
        return HomePage();
    }
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
                  MaterialPageRoute(
                    builder: (_) => const MarketInsightsPage(),
                  ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(primaryColour),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Buy'),
          BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'Sell'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Logistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'My Account',
          ),
        ],
      ),
    );
  }
}
