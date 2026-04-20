import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/recipe/presentation/recipe_detail_screen.dart';
import '../../features/meal_plan/presentation/meal_plan_screen.dart';
import '../../features/shopping_list/presentation/shopping_list_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/cooking/presentation/cooking_screen.dart';
import '../widgets/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.read(authStateProvider);
  return GoRouter(
    initialLocation: authState.isLoggedIn ? '/home' : '/login',
    refreshListenable: authState,
    redirect: (context, state) {
      if (!authState.initialized) return null;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!authState.isLoggedIn && !onAuthPage) return '/login';
      if (authState.isLoggedIn && onAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/explore',
            builder: (_, state) => ExploreScreen(
              fromDay: int.tryParse(state.uri.queryParameters['fromDay'] ?? ''),
              fromMealType: state.uri.queryParameters['fromMealType'],
            ),
          ),
          GoRoute(path: '/meal-plan', builder: (_, __) => const MealPlanScreen()),
          GoRoute(path: '/shopping-list', builder: (_, __) => const ShoppingListScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/recipe/:id',
            builder: (_, state) => RecipeDetailScreen(
              recipeId: state.pathParameters['id']!,
              fromDay: int.tryParse(state.uri.queryParameters['fromDay'] ?? ''),
              fromMealType: state.uri.queryParameters['fromMealType'],
            ),
          ),
          GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
          GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
          GoRoute(
            path: '/cooking/:id',
            builder: (_, state) => CookingScreen(
              recipeId: state.pathParameters['id']!,
              planId: int.tryParse(state.uri.queryParameters['planId'] ?? ''),
              itemId: int.tryParse(state.uri.queryParameters['itemId'] ?? ''),
            ),
          ),
        ],
      ),
    ],
  );
});
