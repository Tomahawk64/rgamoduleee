import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

/// Navigation destination descriptor used by [BottomNavShell].
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.initialLocation,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String initialLocation;
}

// ── Shell that wraps every main-tab screen ─────────────────────────────────────
class BottomNavShell extends StatelessWidget {
  const BottomNavShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavDestination> destinations;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: destinations
            .map(
              (d) => NavigationDestination(
                label: d.label,
                icon: Icon(d.icon),
                selectedIcon: Icon(d.activeIcon),
              ),
            )
            .toList(),
        backgroundColor: AppColors.surface,
        shadowColor: AppColors.overlay,
        elevation: 8,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        animationDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}


