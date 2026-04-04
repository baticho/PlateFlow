import 'package:flutter/material.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  int _selectedDay = 0;
  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('Generate List'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Day selector
          Container(
            height: 72,
            color: cs.surface,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _days.length,
              itemBuilder: (context, idx) => GestureDetector(
                onTap: () => setState(() => _selectedDay = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: _selectedDay == idx ? cs.primary : cs.primary.withAlpha(15),
                  ),
                  child: Text(
                    _days[idx],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _selectedDay == idx ? Colors.white : cs.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Meal slots
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _mealTypes.map((mealType) => _MealSlotCard(mealType: mealType)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  final String mealType;
  const _MealSlotCard({required this.mealType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mealType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Recipe'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: cs.primary.withAlpha(80)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
