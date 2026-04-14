import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented every time a recipe is successfully added to the meal plan.
/// MealPlanScreen listens to this and reloads its data whenever it changes.
final mealPlanRefreshProvider = StateProvider<int>((ref) => 0);
