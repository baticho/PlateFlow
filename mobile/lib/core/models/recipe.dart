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

  factory RecipeSummary.fromJson(Map<String, dynamic> j) {
    return RecipeSummary(
      id: j['id'].toString(),
      title: _resolveTitle(j['translations']),
      description: _resolveDescription(j['translations']),
      imageUrl: j['image_url'],
      totalTimeMinutes: j['total_time_minutes'] ?? 0,
      difficulty: j['difficulty'] ?? 'easy',
      servings: j['servings'] ?? 2,
    );
  }

  static String _resolveTitle(dynamic translations) {
    if (translations == null) return 'Unknown';
    final list = translations as List;
    if (list.isEmpty) return 'Unknown';
    final en = list.firstWhere(
      (t) => t['language_code'] == 'en',
      orElse: () => list.first,
    );
    return en['title'] ?? 'Unknown';
  }

  static String? _resolveDescription(dynamic translations) {
    if (translations == null) return null;
    final list = translations as List;
    if (list.isEmpty) return null;
    final en = list.firstWhere(
      (t) => t['language_code'] == 'en',
      orElse: () => list.first,
    );
    return en['description'];
  }
}

class RecipeIngredient {
  final int id;
  final String name;
  final double quantity;
  final String unit;
  final bool isOptional;

  RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isOptional,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) {
    return RecipeIngredient(
      id: j['id'],
      name: _resolveName(j['ingredient_translations']),
      quantity: (j['quantity'] as num).toDouble(),
      unit: j['unit'] ?? '',
      isOptional: j['is_optional'] ?? false,
    );
  }

  static String _resolveName(dynamic translations) {
    if (translations == null) return 'Unknown';
    final list = translations as List;
    if (list.isEmpty) return 'Unknown';
    final en = list.firstWhere(
      (t) => t['language_code'] == 'en',
      orElse: () => list.first,
    );
    return en['name'] ?? 'Unknown';
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

  factory RecipeStep.fromJson(Map<String, dynamic> j) {
    final translations = j['translations'] as List? ?? [];
    final en = translations.isNotEmpty
        ? translations.firstWhere(
            (t) => t['language_code'] == 'en',
            orElse: () => translations.first,
          )
        : null;
    return RecipeStep(
      order: j['order'] ?? 0,
      instruction: en?['instruction'] ?? '',
      imageUrl: en?['image_url'],
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
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> j) {
    final translations = j['translations'] as List? ?? [];
    final en = translations.isNotEmpty
        ? translations.firstWhere(
            (t) => t['language_code'] == 'en',
            orElse: () => translations.first,
          )
        : null;

    final rawSteps = j['steps'] as List? ?? [];
    final sortedSteps = rawSteps
        .map((s) => RecipeStep.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return RecipeDetail(
      id: j['id'].toString(),
      title: en?['title'] ?? 'Unknown',
      description: en?['description'],
      imageUrl: j['image_url'],
      prepTimeMinutes: j['prep_time_minutes'] ?? 0,
      cookTimeMinutes: j['cook_time_minutes'] ?? 0,
      totalTimeMinutes: j['total_time_minutes'] ?? 0,
      servings: j['servings'] ?? 2,
      difficulty: j['difficulty'] ?? 'easy',
      ingredients: (j['ingredients'] as List? ?? [])
          .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      steps: sortedSteps,
    );
  }
}
