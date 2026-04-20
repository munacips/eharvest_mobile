import 'package:eharvest_mobile/pages/order_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/my_orders_page.dart';
import 'package:eharvest_mobile/services/order_service.dart';
import 'package:eharvest_mobile/services/ai_service.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => MyAccountPageState();
}

class MyAccountPageState extends State<MyAccountPage> {
  User? user;
  Farmer? farmer;
  Buyer? buyer;
  LogisticsProvider? logisticsProvider;
  bool isLoading = true;
  String? errorMessage;
  int _pendingOrders = 0;
  List<Order> _buyerOrders = [];
  bool _aiTrustLoading = false;
  double? _aiTrustScore;
  int? _aiTrustScale;
  int? _aiReviewCount;
  String? _aiTrustError;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final role = await AuthService.getRole();
      if (token == null || userId == null || role == null || role.isEmpty) {
        setState(() {
          errorMessage = 'Authentication error. Please log in again.';
          isLoading = false;
        });
        return;
      }

      final roleKey = role.trim().toLowerCase().replaceAll(' ', '_');
      final endpointByRole = <String, String>{
        'farmer': 'farmers',
        'buyer': 'buyers',
        'logistics_provider': 'logistics-providers',
        'logisticsprovider': 'logistics-providers',
      };
      final endpoint = endpointByRole[roleKey] ?? 'users';

      final uri = Uri.parse('$api$endpoint/$userId');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (roleKey == 'farmer') {
          farmer = Farmer.fromJson(data);
          user = null;
          buyer = null;
          logisticsProvider = null;
          // Fetch pending orders count for farmer
          try {
            final orders = await OrderService.fetchOrdersForFarmer(userId);
            _pendingOrders = orders
                .where((o) => o.status == 'NEW' || o.status == 'PENDING')
                .length;
          } catch (_) {
            _pendingOrders = 0;
          }
        } else if (roleKey == 'buyer') {
          buyer = Buyer.fromJson(data);
          user = null;
          farmer = null;
          logisticsProvider = null;
          // Fetch buyer's orders
          try {
            final ordersUri = Uri.parse('${api}orders/buyer/$userId');
            final ordersResp = await http.get(
              ordersUri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            );
            if (ordersResp.statusCode == 200) {
              final ordersData = json.decode(ordersResp.body);
              if (ordersData is List) {
                _buyerOrders = ordersData
                    .map<Order?>((o) {
                      try {
                        return Order.fromJson(o as Map<String, dynamic>);
                      } catch (e) {
                        return null;
                      }
                    })
                    .whereType<Order>()
                    .toList();
              } else {
                _buyerOrders = [];
              }
            } else {
              _buyerOrders = [];
            }
          } catch (e) {
            _buyerOrders = [];
          }
        } else if (roleKey == 'logistics_provider' ||
            roleKey == 'logisticsprovider') {
          logisticsProvider = LogisticsProvider.fromJson(data);
          user = null;
          farmer = null;
          buyer = null;
        } else {
          user = User.fromJson(data);
          farmer = null;
          buyer = null;
          logisticsProvider = null;
        }
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load user data from /$endpoint/$userId: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading user data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _refreshAiTrustScore() async {
    setState(() {
      _aiTrustLoading = true;
      _aiTrustError = null;
    });
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        throw Exception('User ID unavailable.');
      }
      final response = await AiService.trustScore(userId.toString());
      if (response is Map<String, dynamic>) {
        setState(() {
          _aiTrustScore =
              double.tryParse(response['trust_score']?.toString() ?? '');
          _aiTrustScale = int.tryParse(response['scale']?.toString() ?? '');
          _aiReviewCount =
              int.tryParse(response['review_count']?.toString() ?? '');
        });
      }
    } catch (e) {
      setState(() {
        _aiTrustError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiTrustLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personalInfoTiles = _buildPersonalInfoTiles();
    final businessInfoTiles = _buildBusinessInfoTiles();
    final hasBalances =
        _hasValue(_getField('usdBalance')) ||
        _hasValue(_getField('zigBalance'));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  if (_isFarmer)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        left: 16,
                        right: 16,
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyOrdersPage(),
                            ),
                          );
                          fetchUserData(); // Refresh after returning
                        },
                        child: Card(
                          color: Colors.orange[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 24.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.pending_actions,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Pending Orders',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _pendingOrders.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_isBuyer)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        left: 16,
                        right: 16,
                      ),
                      child: _buildBuyerOrdersCard(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTrustCard(),
                        const SizedBox(height: 16),
                        if (hasBalances) ...[
                          _buildBalancesCard(),
                          const SizedBox(height: 20),
                        ],
                        if (personalInfoTiles.isNotEmpty) ...[
                          _buildInfoSection(
                            "Personal Information",
                            personalInfoTiles,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (businessInfoTiles.isNotEmpty) ...[
                          _buildInfoSection(
                            "Business Details",
                            businessInfoTiles,
                          ),
                          const SizedBox(height: 20),
                        ],
                        const SizedBox(height: 30),
                        _buildLogoutButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _buyerOrdersExpanded = false;

  Widget _buildBuyerOrdersCard() {
    if (_buyerOrders.isEmpty) {
      return Card(
        color: Colors.blue[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No orders found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort orders by orderDate descending
    final sortedOrders = List<Order>.from(_buyerOrders);
    sortedOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final visibleOrders = _buyerOrdersExpanded
        ? sortedOrders
        : sortedOrders.take(5);

    return Card(
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                setState(() {
                  _buyerOrdersExpanded = !_buyerOrdersExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      'My Orders',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _buyerOrdersExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.blue[900],
                    ),
                  ],
                ),
              ),
            ),
            if (_buyerOrdersExpanded || sortedOrders.isNotEmpty)
              const Divider(height: 1, color: Colors.blueGrey),
            ...visibleOrders.map((order) {
              final id = order.id.toString();
              final status = order.status;
              final date = order.orderDate.toString().split(' ').first;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderPage(orderId: order.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6.0,
                    horizontal: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Order #$id',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color: status == 'COMPLETED'
                              ? Colors.green
                              : status == 'CANCELLED'
                              ? Colors.red
                              : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (date.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (!_buyerOrdersExpanded && sortedOrders.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: Text(
                  '+${sortedOrders.length - 5} more orders',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesCard() {
    final usd = _getField('usdBalance');
    final zig = _getField('zigBalance');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("USD Balance", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  usd != null ? "\$$usd" : '-',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(primaryColour),
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 36, color: Colors.grey[300]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ZiG Balance", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  zig != null ? "ZiG $zig" : '-',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(primaryColour),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _getField('fullName');
    final role = _normalizedRole;
    final verified = _getField('verified') == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 24),
      decoration: BoxDecoration(
        color: Color(primaryColour),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 60, color: Colors.grey),
              ),
              if (verified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (name?.toString() ?? '-'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            role.isNotEmpty ? role : '-',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustCard() {
    final trustScore = _getField('trustScore');
    double trustValue = 0;
    if (trustScore != null) {
      trustValue = double.tryParse(trustScore.toString()) ?? 0;
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Trust Score",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trustScore != null ? "$trustScore/100" : '-',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(primaryColour),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: trustValue / 100,
                    backgroundColor: Colors.grey[200],
                    color: Color(primaryColour),
                    strokeWidth: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _aiTrustScore != null
                        ? 'AI Trust: ${_aiTrustScore!.toStringAsFixed(2)}/${_aiTrustScale ?? 5}'
                        : 'AI Trust: -',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                TextButton.icon(
                  onPressed: _aiTrustLoading ? null : _refreshAiTrustScore,
                  icon: _aiTrustLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            if (_aiReviewCount != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reviews: $_aiReviewCount',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            if (_aiTrustError != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _aiTrustError!,
                    style: TextStyle(fontSize: 12, color: Colors.red[700]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  List<Widget> _buildPersonalInfoTiles() {
    final tiles = <Widget>[];
    _addInfoTileIfValue(
      tiles,
      Icons.badge,
      "National ID",
      _getField('nationalId'),
    );
    _addInfoTileIfValue(tiles, Icons.email, "Email", _getField('email'));
    _addInfoTileIfValue(tiles, Icons.phone, "Phone", _getField('phoneNumber'));
    _addInfoTileIfValue(tiles, Icons.home, "Address", _getField('address'));
    return tiles;
  }

  List<Widget> _buildBusinessInfoTiles() {
    final tiles = <Widget>[];
    if (_isFarmer) {
      _addInfoTileIfValue(
        tiles,
        Icons.agriculture,
        "Farm Name",
        _getField('farmName'),
      );
      _addInfoTileIfValue(
        tiles,
        Icons.location_on,
        "Farm Location",
        _getField('farmLocation'),
      );
      _addInfoTileIfValue(
        tiles,
        Icons.check_circle,
        "Successful Sales",
        _getField('successfulSales'),
      );
      _addInfoTileIfValue(
        tiles,
        Icons.cancel,
        "Unsuccessful Sales",
        _getField('unsuccessfulSales'),
      );
    } else if (_isBuyer) {
      _addInfoTileIfValue(
        tiles,
        Icons.business,
        "Company Name",
        _getField('companyName'),
      );
      _addInfoTileIfValue(
        tiles,
        Icons.shopping_cart_checkout,
        "Successful Buys",
        _getField('successfulBuys'),
      );
      _addInfoTileIfValue(
        tiles,
        Icons.remove_shopping_cart,
        "Unsuccessful Buys",
        _getField('unsuccessfulBuys'),
      );
    } else if (_isLogisticsProvider) {
      _addInfoTileIfValue(
        tiles,
        Icons.badge,
        "License Number",
        _getField('licenseNumber'),
      );
      _addInfoTileIfValue(
        tiles,
        Icons.verified_user,
        "Defensive ID",
        _getField('defensiveId'),
      );
    }
    return tiles;
  }

  void _addInfoTileIfValue(
    List<Widget> tiles,
    IconData icon,
    String label,
    Object? value,
  ) {
    if (_hasValue(value)) {
      tiles.add(_infoTile(icon, label, value));
    }
  }

  bool _hasValue(Object? value) {
    if (value == null) return false;
    final text = value.toString().trim();
    return text.isNotEmpty && text.toLowerCase() != 'null';
  }

  String get _normalizedRole =>
      (_getField('role')?.toString().trim().toUpperCase() ?? '');

  bool get _isFarmer => _normalizedRole == 'FARMER';
  bool get _isBuyer => _normalizedRole == 'BUYER';
  bool get _isLogisticsProvider => _normalizedRole == 'LOGISTICS_PROVIDER';

  Object? _getField(String key) {
    // Farmer fields
    if (farmer != null) {
      switch (key) {
        case 'fullName':
          return farmer!.fullName;
        case 'role':
          return farmer!.role;
        case 'verified':
          return farmer!.verified.toString() == 'true';
        case 'nationalId':
          return farmer!.nationalId;
        case 'phoneNumber':
          return farmer!.phoneNumber;
        case 'address':
          return farmer!.address;
        case 'trustScore':
          return farmer!.trustScore.toString();
        case 'usdBalance':
          return null; // Not available in Farmer model
        case 'zigBalance':
          return null; // Not available in Farmer model
        case 'farmName':
          return farmer!.farmName;
        case 'farmLocation':
          return farmer!.farmLocation;
        case 'successfulSales':
          return farmer!.successfulSales.toString();
        case 'unsuccessfulSales':
          return farmer!.unsuccessfulSales.toString();
        case 'companyName':
          return null;
        case 'successfulBuys':
          return null;
        case 'unsuccessfulBuys':
          return null;
        case 'licenseNumber':
          return null;
        case 'defensiveId':
          return null;
        case 'email':
          return farmer!.email;
        default:
          return null;
      }
    }
    // Buyer fields
    if (buyer != null) {
      switch (key) {
        case 'fullName':
          return buyer!.fullName;
        case 'role':
          return buyer!.role;
        case 'verified':
          return buyer!.verified.toString() == 'true';
        case 'nationalId':
          return buyer!.nationalId;
        case 'phoneNumber':
          return buyer!.phoneNumber;
        case 'address':
          return buyer!.address;
        case 'trustScore':
          return buyer!.trustScore.toString();
        case 'usdBalance':
          return null;
        case 'zigBalance':
          return null;
        case 'companyName':
          return buyer!.companyName;
        case 'successfulBuys':
          return buyer!.successfulBuys.toString();
        case 'unsuccessfulBuys':
          return buyer!.unsuccessfulBuys.toString();
        case 'farmName':
          return null;
        case 'farmLocation':
          return null;
        case 'successfulSales':
          return null;
        case 'unsuccessfulSales':
          return null;
        case 'licenseNumber':
          return null;
        case 'defensiveId':
          return null;
        case 'email':
          return buyer!.email;
        default:
          return null;
      }
    }
    // Logistics Provider fields
    if (logisticsProvider != null) {
      switch (key) {
        case 'fullName':
          return logisticsProvider!.fullName;
        case 'role':
          return logisticsProvider!.role;
        case 'verified':
          return logisticsProvider!.verified.toString() == 'true';
        case 'nationalId':
          return logisticsProvider!.nationalId;
        case 'phoneNumber':
          return logisticsProvider!.phoneNumber;
        case 'address':
          return logisticsProvider!.address;
        case 'trustScore':
          return logisticsProvider!.trustScore.toString();
        case 'usdBalance':
          return null;
        case 'zigBalance':
          return null;
        case 'companyName':
          return null;
        case 'farmName':
          return null;
        case 'farmLocation':
          return null;
        case 'successfulSales':
          return null;
        case 'unsuccessfulSales':
          return null;
        case 'successfulBuys':
          return null;
        case 'unsuccessfulBuys':
          return null;
        case 'licenseNumber':
          return logisticsProvider!.licenseNumber;
        case 'defensiveId':
          return logisticsProvider!.defensiveId;
        case 'email':
          return logisticsProvider!.email;
        default:
          return null;
      }
    }
    // Generic User fields
    if (user != null) {
      switch (key) {
        case 'fullName':
          return user!.fullName;
        case 'role':
          return user!.role;
        case 'verified':
          return user!.verified.toString() == 'true';
        case 'nationalId':
          return user!.nationalId;
        case 'phoneNumber':
          return user!.phoneNumber;
        case 'address':
          return user!.address;
        case 'trustScore':
          return user!.trustScore.toString();
        case 'usdBalance':
          return user!.usdBalance.toStringAsFixed(2);
        case 'zigBalance':
          return user!.zigBalance.toStringAsFixed(2);
        case 'companyName':
          return null;
        case 'farmName':
          return null;
        case 'farmLocation':
          return null;
        case 'successfulSales':
          return null;
        case 'unsuccessfulSales':
          return null;
        case 'successfulBuys':
          return null;
        case 'unsuccessfulBuys':
          return null;
        case 'licenseNumber':
          return null;
        case 'defensiveId':
          return null;
        case 'email':
          return user!.email;
        default:
          return null;
      }
    }
    return null;
  }

  Widget _infoTile(IconData icon, String label, Object? value) {
    return ListTile(
      leading: Icon(icon, color: Color(primaryColour)),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value?.toString() ?? '-',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: () {
        // Integrate with your existing logout logic in TabContainer
      },
      icon: const Icon(Icons.logout, color: Colors.red),
      label: const Text(
        "Logout",
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }
}
