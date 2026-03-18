import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/pages/checkout_page.dart';
import 'package:eharvest_mobile/pages/account_page.dart';

class BuyPage extends StatefulWidget {
  const BuyPage({super.key});

  @override
  State<BuyPage> createState() => BuyPageState();
}

class BuyPageState extends State<BuyPage> with WidgetsBindingObserver {
  List<Produce> products = [];
  List<Produce> cart = [];
  bool isLoading = true;
  String? errorMessage;
  // Search & filter state
  String _searchQuery = '';
  String? _categoryFilter;
  double? _minPrice;
  double? _maxPrice;
  DateTime? _harvestFrom;
  DateTime? _harvestTo;
  String? _qualityGrade;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchProducts();
    }
  }

  Future<void> fetchProducts({int page = 0, int size = 20}) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        setState(() {
          errorMessage = 'Authentication token not found. Please log in again.';
          isLoading = false;
        });
        return;
      }

      // Build query parameters from current filters/search
      final Map<String, String> queryParams = {};
      if (_minPrice != null) queryParams['minPrice'] = _minPrice.toString();
      if (_maxPrice != null) queryParams['maxPrice'] = _maxPrice.toString();
      if (_categoryFilter != null && _categoryFilter!.isNotEmpty){

        queryParams['category'] = _categoryFilter!;
      }
      if (_qualityGrade != null && _qualityGrade!.isNotEmpty){

        queryParams['qualityGrade'] = _qualityGrade!;
      }
      if (_harvestFrom != null){

        queryParams['harvestFrom'] = _harvestFrom!
            .toIso8601String()
            .split('T')
            .first;
      }
      if (_harvestTo != null){

        queryParams['harvestTo'] = _harvestTo!
            .toIso8601String()
            .split('T')
            .first;
      }
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
      queryParams['page'] = page.toString();
      queryParams['size'] = size.toString();

      final uri = Uri.parse(
        '${api}produce',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

  

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // Support both raw List responses and paginated responses
        // with a `content` array (Spring-style pagination).
        List<dynamic> dataList;
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded['content'] is List) {
          dataList = decoded['content'] as List<dynamic>;
        } else {
          dataList = [];
        }

      
        setState(() {
          products = dataList
              .map((e) => Produce.fromJson(e as Map<String, dynamic>))
              .toList();
          isLoading = false;
        });
      } else {
        
        setState(() {
          errorMessage = 'Failed to fetch products: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching products: $e';
        isLoading = false;
      });
    }
  }

  void addToCart(Produce product) {
    setState(() {
      cart.add(product);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Search and Filter Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search products...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 500),
                        () {
                          setState(() {
                            _searchQuery = value.trim();
                          });
                          fetchProducts();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => _showFilterSheet(context),
                  icon: const Icon(Icons.filter_list),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(primaryColour).withValues(alpha: 0.1),
                    foregroundColor: Color(primaryColour),
                  ),
                ),
              ],
            ),
          ),

          // 2. Product Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),

      // 3. Floating Checkout Button
      floatingActionButton: cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // Navigate to your checkout page here
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutPage(cart: cart),
                  ),
                );
              },
              backgroundColor: Color(primaryColour),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text("Checkout (${cart.length})"),
            )
          : null,
    );
  }

  Widget _buildProductCard(Produce product) {
    final farmer = product.farmer;
    final farmerName =
        (farmer?.username.isNotEmpty ?? false) ? farmer!.username : 'Unknown';
    final trustScore = farmer?.trustScore;
    final canOpenFarmerProfile = farmer?.id != null && farmer!.id > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Center(
                child: Text(
                  // Produce model does not include an `image` field.
                  // Display first letter of the product name as a placeholder.
                  (product.name.isNotEmpty ? product.name[0] : '?')
                      .toUpperCase(),
                  style: const TextStyle(fontSize: 50),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  product.category,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: canOpenFarmerProfile
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountPage(id: farmer.id),
                            ),
                          );
                        }
                      : null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: canOpenFarmerProfile
                            ? Color(primaryColour)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          farmerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: canOpenFarmerProfile
                                ? Color(primaryColour)
                                : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trustScore != null ? 'Trust: $trustScore' : 'Trust: -',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "\$${product.price.toStringAsFixed(2)} per kg",
                      style: TextStyle(
                        color: Color(primaryColour),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => addToCart(product),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Filter Modal Bottom Sheet
  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        // Controllers for temporary input inside the sheet
        final categoryController = TextEditingController(
          text: _categoryFilter ?? '',
        );
        final minPriceController = TextEditingController(
          text: _minPrice?.toString() ?? '',
        );
        final maxPriceController = TextEditingController(
          text: _maxPrice?.toString() ?? '',
        );
        final qualityController = TextEditingController(
          text: _qualityGrade ?? '',
        );

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filter Products",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. Vegetables)',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Min Price'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Max Price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qualityController,
                decoration: const InputDecoration(
                  labelText: 'Quality Grade (e.g. Grade A)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _harvestFrom ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _harvestFrom = picked;
                          });
                        }
                      },
                      child: Text(
                        _harvestFrom != null
                            ? 'From: ${_harvestFrom!.toIso8601String().split('T').first}'
                            : 'Select Harvest From',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _harvestTo ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _harvestTo = picked;
                          });
                        }
                      },
                      child: Text(
                        _harvestTo != null
                            ? 'To: ${_harvestTo!.toIso8601String().split('T').first}'
                            : 'Select Harvest To',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Apply filters
                        setState(() {
                          _categoryFilter =
                              categoryController.text.trim().isNotEmpty
                              ? categoryController.text.trim()
                              : null;
                          _minPrice = double.tryParse(
                            minPriceController.text.trim(),
                          );
                          _maxPrice = double.tryParse(
                            maxPriceController.text.trim(),
                          );
                          _qualityGrade =
                              qualityController.text.trim().isNotEmpty
                              ? qualityController.text.trim()
                              : null;
                        });
                        fetchProducts();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(primaryColour),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Reset filters
                        setState(() {
                          _categoryFilter = null;
                          _minPrice = null;
                          _maxPrice = null;
                          _harvestFrom = null;
                          _harvestTo = null;
                          _qualityGrade = null;
                        });
                        fetchProducts();
                        Navigator.pop(context);
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


}
