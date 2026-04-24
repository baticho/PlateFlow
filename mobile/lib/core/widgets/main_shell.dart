import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/strings.g.dart';
import '../providers/shopping_list_count_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPress;

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/meal-plan')) return 2;
    if (location.startsWith('/shopping-list')) return 3;
    if (location.startsWith('/profile')) return 4;
    if (location.startsWith('/recipe')) return 1;
    if (location.startsWith('/cooking')) return 0;
    if (location.startsWith('/favorites')) return 4;
    if (location.startsWith('/subscription')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final t = Translations.of(context);
    final itemCount = ref.watch(shoppingListCountProvider).valueOrNull ?? 0;

    Widget shoppingIcon(IconData iconData) {
      if (itemCount <= 0) return Icon(iconData);
      return Badge.count(count: itemCount, child: Icon(iconData));
    }

    final navItems = [
      (t.nav.home, Icons.home_outlined, Icons.home),
      (t.nav.explore, Icons.explore_outlined, Icons.explore),
      (t.nav.mealPlan, Icons.calendar_today_outlined, Icons.calendar_today),
      (t.nav.shopping, Icons.shopping_cart_outlined, Icons.shopping_cart),
      (t.nav.profile, Icons.person_outline, Icons.person),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.common.pressBackAgainToExit),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (idx) {
            const routes = ['/home', '/explore', '/meal-plan', '/shopping-list', '/profile'];
            context.go(routes[idx]);
          },
          destinations: [
            NavigationDestination(icon: Icon(navItems[0].$2), selectedIcon: Icon(navItems[0].$3), label: navItems[0].$1),
            NavigationDestination(icon: Icon(navItems[1].$2), selectedIcon: Icon(navItems[1].$3), label: navItems[1].$1),
            NavigationDestination(icon: Icon(navItems[2].$2), selectedIcon: Icon(navItems[2].$3), label: navItems[2].$1),
            NavigationDestination(
              icon: shoppingIcon(navItems[3].$2),
              selectedIcon: shoppingIcon(navItems[3].$3),
              label: navItems[3].$1,
            ),
            NavigationDestination(icon: Icon(navItems[4].$2), selectedIcon: Icon(navItems[4].$3), label: navItems[4].$1),
          ],
        ),
      ),
    );
  }
}
