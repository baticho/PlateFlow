import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/strings.g.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

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

    final navItems = [
      (t.nav.home, Icons.home_outlined, Icons.home),
      (t.nav.explore, Icons.explore_outlined, Icons.explore),
      (t.nav.mealPlan, Icons.calendar_today_outlined, Icons.calendar_today),
      (t.nav.shopping, Icons.shopping_cart_outlined, Icons.shopping_cart),
      (t.nav.profile, Icons.person_outline, Icons.person),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) {
          const routes = ['/home', '/explore', '/meal-plan', '/shopping-list', '/profile'];
          context.go(routes[idx]);
        },
        destinations: navItems.map((item) => NavigationDestination(
          icon: Icon(item.$2),
          selectedIcon: Icon(item.$3),
          label: item.$1,
        )).toList(),
      ),
    );
  }
}
