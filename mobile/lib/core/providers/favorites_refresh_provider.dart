import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented whenever a recipe is added to / removed from favourites.
/// Screens that show favourites (Home) listen to it and reload.
final favoritesRefreshProvider = StateProvider<int>((ref) => 0);
