import 'package:flutter/material.dart';

class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image app bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Shopska Salad', style: TextStyle(shadows: [Shadow(blurRadius: 4)])),
              background: Container(
                color: cs.primary.withAlpha(30),
                child: Icon(Icons.restaurant, size: 80, color: cs.primary),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
              IconButton(icon: const Icon(Icons.share), onPressed: () {}),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta row
                  Row(children: [
                    _MetaChip(Icons.schedule, '30 min'),
                    const SizedBox(width: 8),
                    _MetaChip(Icons.people_outline, '4 servings'),
                    const SizedBox(width: 8),
                    _MetaChip(Icons.bar_chart, 'Easy'),
                  ]),
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('A classic Bulgarian summer salad with fresh vegetables and feta cheese.'),
                  const SizedBox(height: 24),
                  // Tabs: Ingredients / Steps
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: const [Tab(text: 'Ingredients'), Tab(text: 'Steps')],
                          labelColor: cs.primary,
                          indicatorColor: cs.primary,
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              _IngredientsList(),
                              _StepsList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Add to Shopping List'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text('Add to Meal Plan'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.primary.withAlpha(15),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _IngredientsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ingredients = [
      ('Tomatoes', '300 g'),
      ('Cucumbers', '200 g'),
      ('Bell Pepper', '150 g'),
      ('Feta Cheese', '100 g'),
      ('Olive Oil', '30 ml'),
      ('Salt', 'to taste'),
    ];
    return ListView(
      children: ingredients.map((item) => ListTile(
        leading: const CircleAvatar(radius: 4, backgroundColor: Color(0xFF2E7D32)),
        title: Text(item.$1),
        trailing: Text(item.$2, style: const TextStyle(color: Colors.grey)),
        dense: true,
      )).toList(),
    );
  }
}

class _StepsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      'Dice tomatoes, cucumbers, and bell peppers into small cubes.',
      'Arrange in a bowl.',
      'Add grated feta cheese on top.',
      'Season with salt and drizzle with olive oil.',
    ];
    return ListView.separated(
      itemCount: steps.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) => ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32),
          child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(steps[idx]),
        isThreeLine: true,
      ),
    );
  }
}
