import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:intl/intl.dart' as intl;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/ai_service.dart';

class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => SellPageState();
}

class SellPageState extends State<SellPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to match your Java Produce Entity
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _aiMarketController =
      TextEditingController(text: 'harare');
  final TextEditingController _aiMonthController =
      TextEditingController(text: DateTime.now().month.toString());
  final TextEditingController _aiLatitudeController =
      TextEditingController(text: '-17.8');
  final TextEditingController _aiLongitudeController =
      TextEditingController(text: '31.0');
  final TextEditingController _aiCurrencyController =
      TextEditingController(text: 'USD');

  String _selectedCategory = 'Vegetables';
  String _selectedGrade = 'Grade A';
  DateTime _harvestDate = DateTime.now();
  DateTime _availableDate = DateTime.now();

  final List<String> _categories = [
    'Vegetables',
    'Fruits',
    'Grains',
    'Spices',
    'Tubers',
  ];
  final List<String> _grades = ['Grade A', 'Grade B', 'Grade C'];

  bool _aiLoading = false;
  double? _aiSuggestedPrice;
  double? _aiBasePrice;
  String? _aiError;
  bool _useLiveSignals = true;

  // Function to handle Date Selection
  Future<void> _selectDate(BuildContext context, bool isHarvestDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isHarvestDate) {
          _harvestDate = picked;
        } else {
          _availableDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _aiMarketController.dispose();
    _aiMonthController.dispose();
    _aiLatitudeController.dispose();
    _aiLongitudeController.dispose();
    _aiCurrencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "List New Produce",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                "Enter details below to list your goods on the market.",
              ),
              const SizedBox(height: 20),

              // Image Upload Placeholder
              _buildImageUploader(),

              const SizedBox(height: 20),

              // Produce Name
              _buildTextField(
                _nameController,
                "Produce Name (e.g. Carrots)",
                Icons.eco,
              ),

              const SizedBox(height: 15),

              // Category & Quality Grade Row
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      "Category",
                      _categories,
                      _selectedCategory,
                      (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown(
                      "Quality Grade",
                      _grades,
                      _selectedGrade,
                      (val) => setState(() => _selectedGrade = val!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Quantity & Price Row
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _quantityController,
                      "Quantity (kg)",
                      Icons.scale,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _priceController,
                      "Price per unit (\$)",
                      Icons.payments,
                      isNumber: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildAiSuggestionCard(),

              const SizedBox(height: 15),

              // Description
              _buildTextField(
                _descController,
                "Description",
                Icons.description,
                maxLines: 3,
              ),

              const SizedBox(height: 15),

              // Date Pickers
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      "Harvest Date",
                      _harvestDate,
                      () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateTile(
                      "Available From",
                      _availableDate,
                      () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(primaryColour),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "List Produce on Market",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) => value!.isEmpty ? "Required" : null,
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String currentVal,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: currentVal,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              intl.DateFormat('yyyy-MM-dd').format(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploader() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 40, color: Color(primaryColour)),
          const SizedBox(height: 8),
          const Text(
            "Add Produce Photos",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(primaryColour)),
              const SizedBox(width: 8),
              const Text(
                'AI Price Suggestion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Get a suggested price per kg for this listing.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useLiveSignals,
            onChanged: (value) {
              setState(() {
                _useLiveSignals = value;
              });
            },
            title: const Text(
              'Use live market signals',
              style: TextStyle(fontSize: 13),
            ),
            activeThumbColor: Color(primaryColour),
          ),
          const SizedBox(height: 12),
          _aiTextField(
            controller: _aiMarketController,
            label: 'Market',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _aiTextField(
                  controller: _aiMonthController,
                  label: 'Month (1-12)',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _aiTextField(
                  controller: _aiCurrencyController,
                  label: 'Currency',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _aiTextField(
                  controller: _aiLatitudeController,
                  label: 'Latitude',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _aiTextField(
                  controller: _aiLongitudeController,
                  label: 'Longitude',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _aiLoading ? null : _fetchAiSuggestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(primaryColour),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _aiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Text(
                      'Get Suggestion',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          if (_aiSuggestedPrice != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested price: \$${_aiSuggestedPrice!.toStringAsFixed(2)} per kg',
                    style: TextStyle(
                      color: Color(primaryColour),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _priceController.text =
                        _aiSuggestedPrice!.toStringAsFixed(2);
                  },
                  child: const Text('Use'),
                ),
              ],
            ),
            if (_aiBasePrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Base price: \$${_aiBasePrice!.toStringAsFixed(2)} per kg',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
          if (_aiError != null) ...[
            const SizedBox(height: 8),
            Text(
              _aiError!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
      ),
    );
  }

  Future<void> _fetchAiSuggestion() async {
    final commodity = _nameController.text.trim();
    if (commodity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter produce name first.')),
      );
      return;
    }
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiSuggestedPrice = null;
      _aiBasePrice = null;
    });
    try {
      final payload = {
        'commodity': commodity,
        'market': _aiMarketController.text.trim(),
        'category': _selectedCategory.toLowerCase(),
        'unit': 'KG',
        'month': int.tryParse(_aiMonthController.text.trim()) ?? 1,
        'latitude': double.tryParse(_aiLatitudeController.text.trim()) ?? 0.0,
        'longitude':
            double.tryParse(_aiLongitudeController.text.trim()) ?? 0.0,
        'currency': _aiCurrencyController.text.trim().isEmpty
            ? 'USD'
            : _aiCurrencyController.text.trim(),
        'priceflag': 'actual',
      };
      final response = _useLiveSignals
          ? await AiService.autoPricing({
              ...payload,
              'use_live_signals': true,
            })
          : await AiService.predictPrice(payload);
      double? suggested;
      double? basePrice;
      if (response is Map<String, dynamic>) {
        suggested = double.tryParse(
          response['suggested_price']?.toString() ?? '',
        );
        basePrice = double.tryParse(
          response['base_price']?.toString() ?? '',
        );
      }
      if (suggested == null) {
        throw Exception('Suggestion unavailable.');
      }
      setState(() {
        _aiSuggestedPrice = suggested;
        _aiBasePrice = basePrice;
      });
    } catch (e) {
      setState(() {
        _aiError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiLoading = false;
        });
      }
    }
  }

  Future<void> _createProduce() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication token not found. Please log in again.',
            ),
          ),
        );
        return;
      }

      final produceData = {
        'name': _nameController.text,
        'category': _selectedCategory,
        'description': _descController.text,
        'qualityGrade': _selectedGrade,
        'quantity': double.parse(_quantityController.text),
        'price': double.parse(_priceController.text),
        'availableFrom': _availableDate.toIso8601String().split('T').first,
        'harvestDate': _harvestDate.toIso8601String().split('T').first,
        'farmer': await AuthService.getUserId(),
        'imageUrls': [],
      };

      final response = await http.post(
        Uri.parse('${api}produce'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(produceData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produce listed successfully!')),
        );
        _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to list produce: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _descController.clear();
    _quantityController.clear();
    _priceController.clear();
    setState(() {
      _selectedCategory = 'Vegetables';
      _selectedGrade = 'Grade A';
      _harvestDate = DateTime.now();
      _availableDate = DateTime.now();
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _createProduce();
    }
  }
}
