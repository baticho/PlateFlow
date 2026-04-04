import 'package:flutter/material.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final Map<String, List<_ShoppingItem>> _items = {
    'Produce': [
      _ShoppingItem('Tomatoes', '300 g'),
      _ShoppingItem('Cucumbers', '200 g'),
      _ShoppingItem('Bell Peppers', '150 g'),
    ],
    'Dairy': [
      _ShoppingItem('Feta Cheese', '200 g'),
      _ShoppingItem('Milk', '500 ml'),
    ],
    'Meat': [
      _ShoppingItem('Chicken Breast', '400 g'),
    ],
    'Pantry': [
      _ShoppingItem('Olive Oil', '100 ml'),
      _ShoppingItem('Salt', '—'),
      _ShoppingItem('Rice', '300 g'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = _items.values.fold(0, (s, l) => s + l.length);
    final checked = _items.values.fold(0, (s, l) => s + l.where((i) => i.checked).length);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shopping List', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
            Text('$checked / $total items', style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(160))),
          ],
        ),
        actions: [
          TextButton(onPressed: _clearChecked, child: const Text('Clear Checked')),
        ],
      ),
      body: ListView(
        children: _items.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(entry.key, style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13,
                color: cs.primary, letterSpacing: 0.5,
              )),
            ),
            ...entry.value.asMap().entries.map((e) => CheckboxListTile(
              value: e.value.checked,
              onChanged: (v) => setState(() => e.value.checked = v ?? false),
              title: Text(
                e.value.name,
                style: TextStyle(
                  decoration: e.value.checked ? TextDecoration.lineThrough : null,
                  color: e.value.checked ? Colors.grey : null,
                ),
              ),
              secondary: Text(e.value.quantity, style: const TextStyle(color: Colors.grey)),
              activeColor: cs.primary,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            )),
            const Divider(height: 1),
          ],
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.store_outlined),
        label: const Text('Order Delivery'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _clearChecked() {
    setState(() {
      for (final list in _items.values) {
        list.removeWhere((i) => i.checked);
      }
    });
  }
}

class _ShoppingItem {
  String name;
  String quantity;
  bool checked;
  _ShoppingItem(this.name, this.quantity, {this.checked = false});
}
