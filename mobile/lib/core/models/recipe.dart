class RecipeSummary {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int totalTimeMinutes;
  final String difficulty;
  final int servings;

  RecipeSummary({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.totalTimeMinutes,
    required this.difficulty,
    required this.servings,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> j, {String lang = 'en'}) {
    return RecipeSummary(
      id: j['id'].toString(),
      title: _resolveTitle(j['translations'], lang),
      description: _resolveDescription(j['translations'], lang),
      imageUrl: j['image_url'],
      totalTimeMinutes: j['total_time_minutes'] ?? 0,
      difficulty: j['difficulty'] ?? 'easy',
      servings: j['servings'] ?? 4,
    );
  }

  static String _resolveTitle(dynamic translations, String lang) {
    if (translations == null) return 'Unknown';
    final list = translations as List;
    if (list.isEmpty) return 'Unknown';
    final match = list.firstWhere(
      (t) => t['language_code'] == lang,
      orElse: () => list.firstWhere(
        (t) => t['language_code'] == 'en',
        orElse: () => list.first,
      ),
    );
    return match['title'] ?? 'Unknown';
  }

  static String? _resolveDescription(dynamic translations, String lang) {
    if (translations == null) return null;
    final list = translations as List;
    if (list.isEmpty) return null;
    final match = list.firstWhere(
      (t) => t['language_code'] == lang,
      orElse: () => list.firstWhere(
        (t) => t['language_code'] == 'en',
        orElse: () => list.first,
      ),
    );
    return match['description'];
  }
}

class RecipeIngredient {
  final int id;
  final String name;
  final double quantity;
  final String unit;
  final bool isOptional;
  final String? imageUrl;
  final String? category;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isOptional,
    this.imageUrl,
    this.category,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j, {String lang = 'en'}) {
    return RecipeIngredient(
      id: j['id'],
      name: _resolveName(j['ingredient_translations'], lang),
      quantity: (j['quantity'] as num).toDouble(),
      unit: j['unit'] ?? '',
      isOptional: j['is_optional'] ?? false,
      category: j['ingredient_category'] as String?,
      caloriesPer100g: (j['calories_per_100g'] as num?)?.toDouble(),
      proteinPer100g: (j['protein_per_100g'] as num?)?.toDouble(),
      carbsPer100g: (j['carbs_per_100g'] as num?)?.toDouble(),
      fatPer100g: (j['fat_per_100g'] as num?)?.toDouble(),
      imageUrl: j['ingredient_image_url'] as String?,
    );
  }

  static String _resolveName(dynamic translations, String lang) {
    if (translations == null) return 'Unknown';
    final list = translations as List;
    if (list.isEmpty) return 'Unknown';
    final match = list.firstWhere(
      (t) => t['language_code'] == lang,
      orElse: () => list.firstWhere(
        (t) => t['language_code'] == 'en',
        orElse: () => list.first,
      ),
    );
    return match['name'] ?? 'Unknown';
  }
}

class RecipeStep {
  final int order;
  final String instruction;
  final String? imageUrl;

  RecipeStep({
    required this.order,
    required this.instruction,
    this.imageUrl,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> j, {String lang = 'en'}) {
    final translations = j['translations'] as List? ?? [];
    final match = translations.isNotEmpty
        ? translations.firstWhere(
            (t) => t['language_code'] == lang,
            orElse: () => translations.firstWhere(
              (t) => t['language_code'] == 'en',
              orElse: () => translations.first,
            ),
          )
        : null;
    return RecipeStep(
      order: j['order'] ?? 0,
      instruction: match?['instruction'] ?? '',
      imageUrl: match?['image_url'],
    );
  }
}

class RecipeDetail {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int totalTimeMinutes;
  final int servings;
  final String difficulty;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final RecipeNutrition? nutrition;

  RecipeDetail({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.totalTimeMinutes,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    this.nutrition,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> j, {String lang = 'en'}) {
    final translations = j['translations'] as List? ?? [];
    final match = translations.isNotEmpty
        ? translations.firstWhere(
            (t) => t['language_code'] == lang,
            orElse: () => translations.firstWhere(
              (t) => t['language_code'] == 'en',
              orElse: () => translations.first,
            ),
          )
        : null;

    final rawSteps = j['steps'] as List? ?? [];
    final sortedSteps = rawSteps
        .map((s) => RecipeStep.fromJson(s as Map<String, dynamic>, lang: lang))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return RecipeDetail(
      id: j['id'].toString(),
      title: match?['title'] ?? 'Unknown',
      description: match?['description'],
      imageUrl: j['image_url'],
      prepTimeMinutes: j['prep_time_minutes'] ?? 0,
      cookTimeMinutes: j['cook_time_minutes'] ?? 0,
      totalTimeMinutes: j['total_time_minutes'] ?? 0,
      servings: j['servings'] ?? 4,
      difficulty: j['difficulty'] ?? 'easy',
      ingredients: (j['ingredients'] as List? ?? [])
          .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList(),
      steps: sortedSteps,
      nutrition: RecipeNutrition.fromJson(j),
    );
  }
}

/// Nutrition for one serving of a recipe.
class RecipeNutrition {
  final double calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? saturatedFat;
  final double? sodiumMg;

  const RecipeNutrition({
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.saturatedFat,
    this.sodiumMg,
  });

  /// null when the recipe has no nutrition data
  static RecipeNutrition? fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    final calories = d('calories');
    if (calories == null) return null;
    return RecipeNutrition(
      calories: calories,
      protein: d('protein_g'),
      carbs: d('carbs_g'),
      fat: d('fat_g'),
      fiber: d('fiber_g'),
      sugar: d('sugar_g'),
      saturatedFat: d('saturated_fat_g'),
      sodiumMg: d('sodium_mg'),
    );
  }
}
