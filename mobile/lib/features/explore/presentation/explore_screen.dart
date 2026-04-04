import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Salads', 'icon': Icons.eco, 'color': Color(0xFF4CAF50)},
    {'name': 'Pasta', 'icon': Icons.ramen_dining, 'color': Color(0xFFFF7043)},
    {'name': 'Soups', 'icon': Icons.soup_kitchen, 'color': Color(0xFF29B6F6)},
    {'name': 'Grill', 'icon': Icons.outdoor_grill, 'color': Color(0xFFEF5350)},
    {'name': 'Desserts', 'icon': Icons.cake, 'color': Color(0xFFAB47BC)},
    {'name': 'Breakfast', 'icon': Icons.breakfast_dining, 'color': Color(0xFFFFA726)},
    {'name': 'Vegan', 'icon': Icons.spa, 'color': Color(0xFF66BB6A)},
    {'name': 'Quick', 'icon': Icons.timer, 'color': Color(0xFF26C6DA)},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Explore', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search bar
          SearchBar(
            controller: _searchCtrl,
            hintText: 'Search recipes, ingredients...',
            leading: const Icon(Icons.search),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
            onSubmitted: (q) {/* navigate to search results */},
          ),
          const SizedBox(height: 24),
          // Categories grid
          Text('Categories', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              return GestureDetector(
                onTap: () {},
                child: Column(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: (cat['color'] as Color).withAlpha(30),
                      ),
                      child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(cat['name'] as String, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Cuisines by continent
          Text('Cuisines', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...['🇧🇬 Bulgarian', '🇮🇹 Italian', '🇯🇵 Japanese', '🇲🇽 Mexican', '🇬🇷 Greek'].map(
            (c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primary.withAlpha(20),
                child: Icon(Icons.restaurant, color: cs.primary, size: 20),
              ),
              title: Text(c),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
