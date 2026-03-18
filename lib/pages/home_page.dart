import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart'; // Assuming primaryColour is here

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart Farming, Connected Markets',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // AI INSIGHT CARD
            _buildAIInsightCard(),

            const SizedBox(height: 24),

            // TWO COLUMN SECTION (Active Orders & Recommendations)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSectionCard('ACTIVE ORDERS', _buildOrderList())),
                const SizedBox(width: 12),
                Expanded(child: _buildSectionCard('RECOMMENDED', _buildRecommendationList())),
              ],
            ),

            const SizedBox(height: 24),

            // SEARCH BAR
            TextField(
              decoration: InputDecoration(
                hintText: 'Find produce, buyers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(primaryColour).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune, color: Color(primaryColour)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // CATEGORIES
            const Text(
              'Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCategoryRow(),
          ],
        ),
      ),
    );
  }

  // 1. Large AI Insight Card
  Widget _buildAIInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(primaryColour).withOpacity(0.2), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(primaryColour).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.trending_up, color: Colors.green),
                    SizedBox(width: 8),
                    Text('MARKET ALERT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TOMATOES: +10%\nNEXT WEEK',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text('Based on AI Market Analysis', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Color(primaryColour),
                child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 8),
              const Text('QUICK SELL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  // 2. Generic Section Wrapper
  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  // 3. Placeholder for Active Orders
  Widget _buildOrderList() {
    return Column(
      children: [
        _orderItem(Icons.local_shipping, 'Apples', 'In Transit'),
        const Divider(),
        _orderItem(Icons.payments, 'Maize', 'Pending'),
      ],
    );
  }

  Widget _orderItem(IconData icon, String title, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(primaryColour)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Text(status, style: const TextStyle(fontSize: 10, color: Colors.orange)),
        ],
      ),
    );
  }

  // 4. Placeholder for Recommendations
  Widget _buildRecommendationList() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _recIcon('🥑', 'Avocado'),
        _recIcon('🌶️', 'Peppers'),
      ],
    );
  }

  Widget _recIcon(String emoji, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  // 5. Category Icons
  Widget _buildCategoryRow() {
    List<Map<String, dynamic>> cats = [
      {'icon': Icons.apple, 'name': 'Fruits'},
      {'icon': Icons.grass, 'name': 'Grains'},
      {'icon': Icons.eco, 'name': 'Veg'},
      {'icon': Icons.bakery_dining, 'name': 'Spices'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: cats.map((c) => Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: Icon(c['icon'], color: Color(primaryColour)),
          ),
          const SizedBox(height: 4),
          Text(c['name'], style: const TextStyle(fontSize: 12)),
        ],
      )).toList(),
    );
  }
}