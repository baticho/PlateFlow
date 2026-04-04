import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85,
        ),
        itemCount: 3,
        itemBuilder: (context, idx) {
          final recipes = ['Shopska Salad', 'Spaghetti Aglio e Olio', 'Moussaka'];
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
                      child: Stack(
                        children: [
                          Center(child: Icon(Icons.restaurant_menu, size: 40, color: cs.primary)),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () {},
                              child: const CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.favorite, color: Colors.red, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(recipes[idx], style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
