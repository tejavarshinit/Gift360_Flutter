import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _categoryChips = [
  'Entertainment',
  'Ecommerce',
  'Fashion & Lifestyle',
  'Food & Beverages',
  'Jewellery',
  'Gaming',
];

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  String _query = '';
  String? _selectedCategory;

  final List<Map<String, dynamic>> _demoStores = const [
    {'name': 'Josalukkas', 'rating': 4.6, 'category': 'Jewellery', 'address': 'MG Road', 'city': 'Bengaluru'},
    {'name': 'Reliance Digital', 'rating': 4.4, 'category': 'Ecommerce', 'address': 'Phoenix Marketcity', 'city': 'Chennai'},
    {'name': 'PVR Cinemas', 'rating': 4.7, 'category': 'Entertainment', 'address': 'VR Mall', 'city': 'Hyderabad'},
    {'name': 'Zara', 'rating': 4.5, 'category': 'Fashion & Lifestyle', 'address': 'Forum Mall', 'city': 'Kolkata'},
    {"name": "Domino's", 'rating': 4.3, 'category': 'Food & Beverages', 'address': 'Park Street', 'city': 'Pune'},
    {'name': 'Play Arena', 'rating': 4.8, 'category': 'Gaming', 'address': 'HSR Layout', 'city': 'Bengaluru'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredStores = _demoStores.where((store) {
      final matchesQuery = _query.isEmpty ||
          store['name'].toString().toLowerCase().contains(_query.toLowerCase()) ||
          store['address'].toString().toLowerCase().contains(_query.toLowerCase());
      final matchesCategory = _selectedCategory == null || store['category'] == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
            color: const Color(0xFFF6F7FB),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF11131D)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Nearby Stores',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF11131D)),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD8D8FF), Color(0xFFB9C7FF), Color(0xFFE7D7FF)]),
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FD),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search nearby gift stores...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categoryChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categoryChips[index];
                final active = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = active ? null : cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF6A53FF) : const Color(0xFFEEF0FF),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: active ? [BoxShadow(color: const Color(0xFF6A53FF).withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))] : null,
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : const Color(0xFF404555),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Map card placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nearby Stores Map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF171A24))),
                const SizedBox(height: 8),
                Container(
                  height: 168,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF2F5FF), Color(0xFFE8ECFF), Color(0xFFDFE8FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 28, offset: const Offset(0, 12))],
                  ),
                  child: Stack(
                    children: [
                      // Grid lines
                      Positioned(left: 0, top: 84, right: 0, child: Container(height: 1, color: const Color(0xFFCFD6F3).withValues(alpha: 0.65))),
                      Positioned(left: 0, top: 44, right: 0, child: Container(height: 1, color: const Color(0xFFD8DEF5).withValues(alpha: 0.65))),
                      Positioned(left: 0, top: 124, right: 0, child: Container(height: 1, color: const Color(0xFFD8DEF5).withValues(alpha: 0.65))),
                      Positioned(left: 72, top: 0, bottom: 0, child: Container(width: 1, color: const Color(0xFFD8DEF5).withValues(alpha: 0.65))),
                      Positioned(left: 196, top: 0, bottom: 0, child: Container(width: 1, color: const Color(0xFFD8DEF5).withValues(alpha: 0.65))),
                      Positioned(left: 308, top: 0, bottom: 0, child: Container(width: 1, color: const Color(0xFFD8DEF5).withValues(alpha: 0.65))),
                      // Pins
                      ..._buildMapPins(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Trending Stores near you', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF171A24))),
            ),
          ),

          const SizedBox(height: 12),

          // Store list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: filteredStores.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildStoreCard(filteredStores[index]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMapPins() {
    final positions = [
      Offset(MediaQuery.of(context).size.width * 0.22, 46),
      Offset(MediaQuery.of(context).size.width * 0.39, 97),
      Offset(MediaQuery.of(context).size.width * 0.68, 64),
    ];
    return positions.map((pos) {
      return Positioned(
        left: pos.dx - 16,
        top: pos.dy - 32,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF6A53FF),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFF6A53FF).withValues(alpha: 0.24), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 16),
        ),
      );
    }).toList();
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [Color(0xFFEEF0FF), Color(0xFFDDE4FF)]),
            ),
            child: Center(
              child: Text(
                store['name'].toString().substring(0, 2).toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF5F6380)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF171A24))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFFFB545)),
                    const SizedBox(width: 4),
                    Text('${store['rating']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF646B7D))),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${store['address']}, ${store['city']}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B90A4)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: const Text('Get Directions →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6A53FF))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
