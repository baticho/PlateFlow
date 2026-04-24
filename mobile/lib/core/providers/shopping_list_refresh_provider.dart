import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented every time the shopping list is successfully regenerated.
/// ShoppingListScreen listens to this and reloads whenever it changes.
final shoppingListRefreshProvider = StateProvider<int>((ref) => 0);
