import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('PlateFlow', style: TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: cs.primary,
        )),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Weekly suggestions section
          Text("This Week's Picks", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) => _RecipeCard(
                title: 'Recipe ${idx + 1}',
                time: '${30 + idx * 5} min',
                color: [Colors.green, Colors.orange, Colors.blue, Colors.purple, Colors.teal][idx % 5],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quick meals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quick Meals', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              TextButton(onPressed: () => context.go('/explore'), child: const Text('See all')),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85,
            ),
            itemCount: 4,
            itemBuilder: (context, idx) => _RecipeGridCard(
              title: ['Shopska Salad', 'Spaghetti', 'Moussaka', 'Grilled Chicken'][idx],
              time: ['30 min', '25 min', '55 min', '40 min'][idx],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final String title;
  final String time;
  final Color color;
  const _RecipeCard({required this.title, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/recipe/sample-id'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withAlpha(30),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: color.withAlpha(60),
              ),
              child: Center(child: Icon(Icons.restaurant, size: 48, color: color)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeGridCard extends StatelessWidget {
  final String title;
  final String time;
  const _RecipeGridCard({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/recipe/sample-id'),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  color: cs.primary.withAlpha(20),
                ),
                child: Center(child: Icon(Icons.restaurant_menu, size: 40, color: cs.primary)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
