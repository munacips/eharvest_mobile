import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/admin_models.dart';
import 'package:eharvest_mobile/pages/admin/admin_disputes_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_logistics_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_order_items_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_orders_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_produce_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_reviews_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_role_users_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_subscriptions_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_transactions_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_users_page.dart';
import 'package:eharvest_mobile/pages/admin/admin_vehicles_page.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:eharvest_mobile/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  AdminDashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await AdminService.fetchDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openSection(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ResponsiveContent(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline, color: Colors.red[400], size: 56),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final stats = _stats!;
    final sections = _sections(stats);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Color(textCharcoalGrey),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform overview and management tools',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _statColumns(context),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            delegate: SliverChildListDelegate(_statCards(stats)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Management',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _sectionColumns(context),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = sections[index];
                return _SectionCard(
                  icon: section.icon,
                  title: section.title,
                  subtitle: section.subtitle,
                  badge: section.badge,
                  onTap: () => _openSection(section.page),
                );
              },
              childCount: sections.length,
            ),
          ),
        ),
      ],
    );
  }

  int _statColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= ResponsiveBreakpoints.wideDesktop) return 4;
    if (width >= ResponsiveBreakpoints.desktop) return 3;
    if (width >= ResponsiveBreakpoints.tablet) return 2;
    return 2;
  }

  int _sectionColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= ResponsiveBreakpoints.wideDesktop) return 4;
    if (width >= ResponsiveBreakpoints.desktop) return 3;
    if (width >= ResponsiveBreakpoints.tablet) return 2;
    return 2;
  }

  List<Widget> _statCards(AdminDashboardStats stats) {
    return [
      _StatCard(label: 'Users', value: stats.totalUsers, icon: Icons.people),
      _StatCard(label: 'Farmers', value: stats.totalFarmers, icon: Icons.agriculture),
      _StatCard(label: 'Buyers', value: stats.totalBuyers, icon: Icons.store),
      _StatCard(
        label: 'Logistics',
        value: stats.totalLogisticsProviders,
        icon: Icons.local_shipping,
      ),
      _StatCard(label: 'Admins', value: stats.totalAdmins, icon: Icons.admin_panel_settings),
      _StatCard(label: 'Produce', value: stats.totalProduce, icon: Icons.eco),
      _StatCard(label: 'Vehicles', value: stats.totalVehicles, icon: Icons.directions_car),
      _StatCard(label: 'Orders', value: stats.totalOrders, icon: Icons.receipt_long),
      _StatCard(label: 'Reviews', value: stats.totalReviews, icon: Icons.star),
      _StatCard(
        label: 'Disputes',
        value: stats.totalDisputeReports,
        icon: Icons.report_problem,
        highlight: stats.unattendedDisputeReports > 0,
        subtitle: '${stats.unattendedDisputeReports} unattended',
      ),
      _StatCard(
        label: 'Unverified',
        value: stats.unverifiedUsers,
        icon: Icons.verified_user_outlined,
        highlight: stats.unverifiedUsers > 0,
      ),
    ];
  }

  List<_AdminSection> _sections(AdminDashboardStats stats) {
    return [
      _AdminSection(
        icon: Icons.people,
        title: 'Users',
        subtitle: 'All platform users',
        page: const AdminUsersPage(),
      ),
      _AdminSection(
        icon: Icons.agriculture,
        title: 'Farmers',
        subtitle: 'Search and manage farmers',
        page: const AdminRoleUsersPage(role: AdminRoleUsersPageRole.farmer),
      ),
      _AdminSection(
        icon: Icons.store,
        title: 'Buyers',
        subtitle: 'Search and manage buyers',
        page: const AdminRoleUsersPage(role: AdminRoleUsersPageRole.buyer),
      ),
      _AdminSection(
        icon: Icons.local_shipping_outlined,
        title: 'Logistics Providers',
        subtitle: 'Provider accounts',
        page: const AdminRoleUsersPage(
          role: AdminRoleUsersPageRole.logisticsProvider,
        ),
      ),
      _AdminSection(
        icon: Icons.eco,
        title: 'Produce',
        subtitle: 'Catalog listings',
        page: const AdminProducePage(),
      ),
      _AdminSection(
        icon: Icons.directions_car,
        title: 'Vehicles',
        subtitle: 'Fleet registry',
        page: const AdminVehiclesPage(),
      ),
      _AdminSection(
        icon: Icons.receipt_long,
        title: 'Orders',
        subtitle: 'Order management',
        page: const AdminOrdersPage(),
      ),
      _AdminSection(
        icon: Icons.list_alt,
        title: 'Order Items',
        subtitle: 'Line items',
        page: const AdminOrderItemsPage(),
      ),
      _AdminSection(
        icon: Icons.star,
        title: 'Reviews',
        subtitle: 'Ratings and feedback',
        page: const AdminReviewsPage(),
      ),
      _AdminSection(
        icon: Icons.local_shipping,
        title: 'Logistics Requests',
        subtitle: 'Delivery requests',
        page: const AdminLogisticsPage(),
      ),
      _AdminSection(
        icon: Icons.repeat,
        title: 'Subscriptions',
        subtitle: 'Recurring deliveries',
        page: const AdminSubscriptionsPage(),
      ),
      _AdminSection(
        icon: Icons.report_problem,
        title: 'Dispute Reports',
        subtitle: 'Support and resolution',
        badge: stats.unattendedDisputeReports > 0
            ? stats.unattendedDisputeReports.toString()
            : null,
        page: const AdminDisputesPage(),
      ),
      _AdminSection(
        icon: Icons.payments,
        title: 'Transactions',
        subtitle: 'Payment history',
        page: const AdminTransactionsPage(),
      ),
    ];
  }
}

class _AdminSection {
  const _AdminSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final String? badge;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.highlight = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final String? subtitle;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: highlight ? Colors.orange[800] : Color(primaryColour),
                ),
                const Spacer(),
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(primaryColour).withValues(alpha: 0.12),
                    child: Icon(icon, color: Color(primaryColour)),
                  ),
                  if (badge != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
