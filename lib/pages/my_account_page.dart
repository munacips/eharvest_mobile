import 'package:eharvest_mobile/pages/order_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/logistics_list.dart';
import 'package:eharvest_mobile/pages/logistics_request_page.dart';
import 'package:eharvest_mobile/pages/my_orders_page.dart';
import 'package:eharvest_mobile/services/order_service.dart';
import 'package:eharvest_mobile/services/payment_redirect_stub.dart'
    if (dart.library.html) 'package:eharvest_mobile/services/payment_redirect_web.dart';
import 'package:eharvest_mobile/services/payment_service.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _currentLogisticsRequests = 0;
  List<Order> _buyerOrders = [];
  List<Map<String, dynamic>> _presentDeliveries = [];
  List<Map<String, dynamic>> _pastDeliveries = [];
  bool _aiTrustLoading = false;
  double? _aiTrustScore;
  int? _aiTrustScale;
  int? _aiReviewCount;
  String? _aiTrustError;
  bool _driverDeliveriesExpanded = false;
  String _resolvedRoleKey = '';
  final TextEditingController _depositAmountController =
      TextEditingController();
  final TextEditingController _withdrawAmountController =
      TextEditingController();
  String _depositCurrency = 'USD';
  String _withdrawCurrency = 'USD';
  bool _depositLoading = false;
  bool _withdrawLoading = false;
  String? _paymentMessage;
  String? _paymentError;

  String _normalizeRoleKey(String rawRole) {
    final normalized = rawRole.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final baseRole = normalized.startsWith('role_')
        ? normalized.substring('role_'.length)
        : normalized;

    // Canonical DB role keys are farmer, buyer, and logistics.
    switch (baseRole) {
      case 'farmer':
      case 'buyer':
        return baseRole;
      case 'logistics':
      case 'logistics_provider':
      case 'logisticsprovider':
        return 'logistics';
      default:
        return baseRole;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  @override
  void dispose() {
    _depositAmountController.dispose();
    _withdrawAmountController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    _resolvedRoleKey = '';
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

      final roleKey = _normalizeRoleKey(role);
      _resolvedRoleKey = roleKey;
      final endpointByRole = <String, String>{
        'farmer': 'farmers',
        'buyer': 'buyers',
        'logistics': 'logistics-providers',
      };
      final preferredEndpoint = endpointByRole[roleKey];
      final candidateEndpoints = <String>[
        if (preferredEndpoint != null) preferredEndpoint,
        'farmers',
        'buyers',
        'logistics-providers',
        'users',
      ];

      final triedStatuses = <String>[];
      String? resolvedEndpoint;
      dynamic resolvedData;

      for (final endpoint in candidateEndpoints) {
        final uri = Uri.parse('$api$endpoint/$userId');
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        triedStatuses.add('/$endpoint/$userId: ${response.statusCode}');
        if (response.statusCode == 200) {
          resolvedEndpoint = endpoint;
          resolvedData = json.decode(response.body);
          break;
        }
      }

      if (resolvedData != null && resolvedEndpoint != null) {
        if (resolvedData is! Map<String, dynamic>) {
          setState(() {
            errorMessage = 'Invalid user data format received from server.';
            isLoading = false;
          });
          return;
        }
        final data = resolvedData;
        final responseRoleKey = _normalizeRoleKey(
          data['role']?.toString() ?? '',
        );
        final effectiveRoleKey = responseRoleKey.isNotEmpty
            ? responseRoleKey
            : roleKey;
        _resolvedRoleKey = effectiveRoleKey;

        if (effectiveRoleKey == 'farmer' || resolvedEndpoint == 'farmers') {
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
        } else if (effectiveRoleKey == 'buyer' ||
            resolvedEndpoint == 'buyers') {
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
        } else if (effectiveRoleKey == 'logistics' ||
            resolvedEndpoint == 'logistics-providers') {
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
        if (effectiveRoleKey == 'logistics' ||
            resolvedEndpoint == 'logistics-providers') {
          await _fetchDriverLogisticsData(token, userId);
        } else {
          _currentLogisticsRequests = 0;
          _presentDeliveries = [];
          _pastDeliveries = [];
        }
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load user data. Tried: ${triedStatuses.join(', ')}';
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
          _aiTrustScore = double.tryParse(
            response['trust_score']?.toString() ?? '',
          );
          _aiTrustScale = int.tryParse(response['scale']?.toString() ?? '');
          _aiReviewCount = int.tryParse(
            response['review_count']?.toString() ?? '',
          );
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

  Future<void> _submitDeposit() async {
    final amount = double.tryParse(_depositAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _paymentError = 'Enter a deposit amount greater than 0.');
      return;
    }

    setState(() {
      _depositLoading = true;
      _paymentError = null;
      _paymentMessage = null;
    });

    try {
      final payload = _paymentPayload(
        amount: amount,
        currency: _depositCurrency,
        type: 'DEPOSIT',
      );
      final result = await PaymentService.initiatePayment(payload);
      final redirectUrl = result['redirectUrl']?.toString();
      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        redirectToPayment(redirectUrl);
        return;
      }
      if (!mounted) return;
      setState(() {
        _paymentMessage =
            'Deposit created with status ${result['status'] ?? 'PENDING'}.';
      });
      await fetchUserData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _depositLoading = false);
      }
    }
  }

  Future<void> _submitWithdrawal() async {
    final amount = double.tryParse(_withdrawAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _paymentError = 'Enter a withdrawal amount greater than 0.');
      return;
    }

    final balance = _balanceForCurrency(_withdrawCurrency);
    if (amount > balance) {
      setState(
        () => _paymentError =
            'Withdrawal amount exceeds your $_withdrawCurrency balance.',
      );
      return;
    }

    setState(() {
      _withdrawLoading = true;
      _paymentError = null;
      _paymentMessage = null;
    });

    try {
      final payload = _paymentPayload(
        amount: amount,
        currency: _withdrawCurrency,
        type: 'WITHDRAWAL',
      );
      final result = await PaymentService.initiatePayment(payload);
      if (!mounted) return;
      setState(() {
        _paymentMessage =
            'Withdrawal submitted with status ${result['status'] ?? 'PENDING'}.';
      });
      await fetchUserData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _withdrawLoading = false);
      }
    }
  }

  Map<String, dynamic> _paymentPayload({
    required double amount,
    required String currency,
    required String type,
  }) {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Authentication error. Please log in again.');
    }
    return {
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'type': type,
      'email': _getField('email')?.toString() ?? '',
      'phoneNumber': _getField('phoneNumber')?.toString() ?? '',
    };
  }

  int? get _currentUserId {
    if (farmer != null) return farmer!.id;
    if (buyer != null) return buyer!.id;
    if (logisticsProvider != null) return logisticsProvider!.id;
    return user?.id;
  }

  double _balanceForCurrency(String currency) {
    final value = currency == 'ZIG'
        ? _getField('zigBalance')
        : _getField('usdBalance');
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _fetchDriverLogisticsData(String token, int providerId) async {
    try {
      final response = await http.get(
        Uri.parse('${api}logistics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        _currentLogisticsRequests = 0;
        _presentDeliveries = [];
        _pastDeliveries = [];
        return;
      }

      final items = _decodeLogisticsItems(json.decode(response.body));
      final present = items
          .where(
            (item) =>
                _isAssignedToProvider(item, providerId) &&
                _isPresentDelivery(item),
          )
          .toList();
      final past = items
          .where(
            (item) =>
                _isAssignedToProvider(item, providerId) &&
                _isPastDelivery(item),
          )
          .toList();

      _sortLogisticsItems(present);
      _sortLogisticsItems(past);

      _currentLogisticsRequests = items
          .where(_isPendingLogisticsRequest)
          .length;
      _presentDeliveries = present;
      _pastDeliveries = past;
    } catch (_) {
      _currentLogisticsRequests = 0;
      _presentDeliveries = [];
      _pastDeliveries = [];
    }
  }

  List<Map<String, dynamic>> _decodeLogisticsItems(dynamic payload) {
    List<dynamic> items = <dynamic>[];
    if (payload is List) {
      items = payload;
    } else if (payload is Map<String, dynamic> && payload['content'] is List) {
      items = payload['content'] as List<dynamic>;
    }

    return items
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  bool _isPendingLogisticsRequest(Map<String, dynamic> request) {
    final status = _normalizeStatus(_readString(request, <String>['status']));
    const closedStatuses = <String>{
      'accepted',
      'assigned',
      'rejected',
      'cancelled',
      'in_transit',
      'delivered',
      'completed',
    };
    if (status.isEmpty) {
      return true;
    }
    return !closedStatuses.contains(status);
  }

  bool _isAssignedToProvider(Map<String, dynamic> request, int providerId) {
    final assignedProvider = _readMap(request, <String>[
      'assignedProvider',
      'assigned_provider',
      'provider',
    ]);
    if (assignedProvider == null) {
      return false;
    }

    final assignedProviderId = _readInt(assignedProvider, <String>[
      'id',
      'providerId',
      'provider_id',
    ], fallback: -1);
    return assignedProviderId == providerId;
  }

  bool _isPresentDelivery(Map<String, dynamic> request) {
    final status = _normalizeStatus(_readString(request, <String>['status']));
    return <String>{'accepted', 'assigned', 'in_transit'}.contains(status);
  }

  bool _isPastDelivery(Map<String, dynamic> request) {
    final status = _normalizeStatus(_readString(request, <String>['status']));
    return <String>{'delivered', 'completed'}.contains(status);
  }

  void _sortLogisticsItems(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final aDate = _readDate(a);
      final bDate = _readDate(b);
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      return _readInt(b, <String>['id']).compareTo(_readInt(a, <String>['id']));
    });
  }

  DateTime? _readDate(Map<String, dynamic> request) {
    final order = _readMap(request, <String>['order']);
    final raw = _readString(order, <String>[
      'orderDate',
      'order_date',
      'createdAt',
      'created_at',
    ]);
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }
    }
    return '';
  }

  int _readInt(
    Map<String, dynamic>? map,
    List<String> keys, {
    int fallback = 0,
  }) {
    final text = _readString(map, keys);
    if (text.isEmpty) return fallback;
    return int.tryParse(text) ?? fallback;
  }

  bool _readBool(Map<String, dynamic>? map, List<String> keys) {
    final text = _readString(map, keys).toLowerCase();
    return text == 'true' || text == '1';
  }

  double _readDouble(Map<String, dynamic>? map, List<String> keys) {
    final text = _readString(map, keys);
    if (text.isEmpty) return 0;
    return double.tryParse(text) ?? 0;
  }

  Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return null;
  }

  String _formatDeliveryStatus(String rawStatus) {
    final normalized = _normalizeStatus(rawStatus);
    if (normalized.isEmpty) {
      return 'UNKNOWN';
    }
    return normalized
        .split('_')
        .map((part) => part.isEmpty ? part : part.toUpperCase())
        .join(' ');
  }

  Color _deliveryStatusColor(String rawStatus) {
    switch (_normalizeStatus(rawStatus)) {
      case 'accepted':
      case 'assigned':
        return Colors.blue;
      case 'in_transit':
        return Colors.orange;
      case 'delivered':
      case 'completed':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  LogisticsRequest _toLogisticsRequest(Map<String, dynamic> request) {
    final assignedProviderJson = _readMap(request, <String>[
      'assignedProvider',
      'assigned_provider',
      'provider',
    ]);

    return LogisticsRequest(
      id: _readInt(request, <String>['id']),
      pickupLocation: _readString(request, <String>[
        'pickupLocation',
        'pickup_location',
      ]),
      deliveryLocation: _readString(request, <String>[
        'deliveryLocation',
        'delivery_location',
      ]),
      status: _readString(request, <String>['status']),
      cost: _readDouble(request, <String>['cost']),
      escrowHeld: _readBool(request, <String>['escrowHeld', 'escrow_held']),
      escrowReleased: _readBool(request, <String>[
        'escrowReleased',
        'escrow_released',
      ]),
      assignedProvider: assignedProviderJson == null
          ? null
          : LogisticsProvider(
              id: _readInt(assignedProviderJson, <String>['id']),
              nationalId: _readString(assignedProviderJson, <String>[
                'nationalId',
                'national_id',
              ]),
              firstName: _readString(assignedProviderJson, <String>[
                'firstName',
                'first_name',
              ]),
              lastName: _readString(assignedProviderJson, <String>[
                'lastName',
                'last_name',
              ]),
              username: _readString(assignedProviderJson, <String>['username']),
              role: _readString(assignedProviderJson, <String>['role']),
              email: _readString(assignedProviderJson, <String>['email']),
              password: _readString(assignedProviderJson, <String>['password']),
              phoneNumber: _readString(assignedProviderJson, <String>[
                'phoneNumber',
                'phone_number',
              ]),
              address: _readString(assignedProviderJson, <String>['address']),
              active: _readBool(assignedProviderJson, <String>['active']),
              verified: _readBool(assignedProviderJson, <String>['verified']),
              trustScore: _readInt(assignedProviderJson, <String>[
                'trustScore',
                'trust_score',
              ]),
              usdBalance: _readDouble(assignedProviderJson, <String>[
                'usdBalance',
                'usd_balance',
              ]),
              zigBalance: _readDouble(assignedProviderJson, <String>[
                'zigBalance',
                'zig_balance',
              ]),
              licenseNumber: _readString(assignedProviderJson, <String>[
                'licenseNumber',
                'license_number',
              ]),
              defensiveId: _readString(assignedProviderJson, <String>[
                'defensiveId',
                'defensive_id',
              ]),
            ),
      order: null,
    );
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
                  if (_showDriverCards)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        left: 16,
                        right: 16,
                      ),
                      child: _buildDriverRequestsCard(),
                    ),
                  if (_showDriverCards)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        left: 16,
                        right: 16,
                      ),
                      child: _buildDriverDeliveriesCard(),
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
                        _buildPaymentsCard(),
                        const SizedBox(height: 20),
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

  Widget _buildDriverRequestsCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogisticsList()),
        );
        fetchUserData();
      },
      child: Card(
        color: Colors.teal[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.teal),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Current Logistics Requests',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentLogisticsRequests.toString(),
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

  Widget _buildDriverDeliveriesCard() {
    final totalDeliveries = _presentDeliveries.length + _pastDeliveries.length;

    return Card(
      color: Colors.green[50],
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
                  _driverDeliveriesExpanded = !_driverDeliveriesExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Deliveries',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                          Text(
                            '${_presentDeliveries.length} present | ${_pastDeliveries.length} past',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _driverDeliveriesExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.green[900],
                    ),
                  ],
                ),
              ),
            ),
            if (_driverDeliveriesExpanded || totalDeliveries > 0)
              const Divider(height: 1, color: Colors.blueGrey),
            if (totalDeliveries == 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
                child: Text(
                  'No accepted deliveries yet.',
                  style: TextStyle(color: Colors.green[900]),
                ),
              )
            else ...[
              _buildDeliveryGroup(
                title: 'Present Deliveries',
                deliveries: _presentDeliveries,
                emptyText: 'No present deliveries.',
              ),
              const Divider(height: 1),
              _buildDeliveryGroup(
                title: 'Past Deliveries',
                deliveries: _pastDeliveries,
                emptyText: 'No past deliveries yet.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryGroup({
    required String title,
    required List<Map<String, dynamic>> deliveries,
    required String emptyText,
  }) {
    final visibleDeliveries = _driverDeliveriesExpanded
        ? deliveries
        : deliveries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (deliveries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                emptyText,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else ...[
            ...visibleDeliveries.map(_buildDeliveryItem),
            if (!_driverDeliveriesExpanded && deliveries.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                child: Text(
                  '+${deliveries.length - 3} more',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryItem(Map<String, dynamic> delivery) {
    final deliveryId = _readInt(delivery, <String>['id']);
    final pickup = _readString(delivery, <String>[
      'pickupLocation',
      'pickup_location',
    ]);
    final dropOff = _readString(delivery, <String>[
      'deliveryLocation',
      'delivery_location',
    ]);
    final status = _readString(delivery, <String>['status']);
    final routeText =
        '${pickup.isEmpty ? 'Unknown pickup' : pickup} -> '
        '${dropOff.isEmpty ? 'Unknown delivery' : dropOff}';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LogisticsRequestPage(
              logisticsRequest: _toLogisticsRequest(delivery),
              allowEditing: false,
            ),
          ),
        );
        fetchUserData();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery #$deliveryId',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    routeText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _deliveryStatusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDeliveryStatus(status),
                style: TextStyle(
                  color: _deliveryStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
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

  Widget _buildPaymentsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Color(primaryColour)),
                const SizedBox(width: 8),
                const Text(
                  'Wallet Payments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _paymentFormRow(
              controller: _depositAmountController,
              currency: _depositCurrency,
              onCurrencyChanged: (value) {
                if (value != null) setState(() => _depositCurrency = value);
              },
              buttonText: 'Deposit',
              loading: _depositLoading,
              onPressed: _submitDeposit,
            ),
            const SizedBox(height: 12),
            _paymentFormRow(
              controller: _withdrawAmountController,
              currency: _withdrawCurrency,
              onCurrencyChanged: (value) {
                if (value != null) setState(() => _withdrawCurrency = value);
              },
              buttonText: 'Withdraw',
              loading: _withdrawLoading,
              onPressed: _submitWithdrawal,
            ),
            if (_paymentError != null) ...[
              const SizedBox(height: 10),
              Text(_paymentError!, style: const TextStyle(color: Colors.red)),
            ],
            if (_paymentMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _paymentMessage!,
                style: TextStyle(color: Color(primaryDarkColour)),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Deposits update after Paynow confirmation. Withdrawals are submitted as pending payouts.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentFormRow({
    required TextEditingController controller,
    required String currency,
    required ValueChanged<String?> onCurrencyChanged,
    required String buttonText,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '$buttonText amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: currency,
          items: const [
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'ZIG', child: Text('ZIG')),
          ],
          onChanged: loading ? null : onCurrencyChanged,
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(buttonText),
        ),
      ],
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

  String get _normalizedRole {
    if (_resolvedRoleKey.isNotEmpty) {
      return _resolvedRoleKey;
    }
    final rawRole = _getField('role')?.toString() ?? '';
    return _normalizeRoleKey(rawRole);
  }

  bool get _isFarmer => _normalizedRole == 'farmer';
  bool get _isBuyer => _normalizedRole == 'buyer';
  bool get _isLogisticsProvider => _normalizedRole == 'logistics';
  bool get _showDriverCards => _isLogisticsProvider;

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
          return farmer!.usdBalance.toStringAsFixed(2);
        case 'zigBalance':
          return farmer!.zigBalance.toStringAsFixed(2);
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
          return buyer!.usdBalance.toStringAsFixed(2);
        case 'zigBalance':
          return buyer!.zigBalance.toStringAsFixed(2);
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
          return logisticsProvider!.usdBalance.toStringAsFixed(2);
        case 'zigBalance':
          return logisticsProvider!.zigBalance.toStringAsFixed(2);
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

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error during logout')));
      }
    }
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: () {
        _logout();
      },
      icon: const Icon(Icons.logout, color: Colors.red),
      label: const Text(
        "Logout",
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }
}
