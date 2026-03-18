import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:intl/intl.dart' as intl;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';

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

              // AI Suggestion Tip
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4),
                child: Text(
                  "✨ AI Suggestion: \$14.50 - \$16.00 for $_selectedGrade Tomatoes",
                  style: TextStyle(
                    color: Color(primaryColour),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

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
