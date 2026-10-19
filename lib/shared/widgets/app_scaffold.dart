import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/security/roles_and_permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'indicators/status_badge.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;
  final int selectedIndex;

  const AppScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = user?.role ?? UserRole.member;

    final navItems = _getNavItems(role, user);

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AJRA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    AppConstants.appFullName,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StatusBadge.fromRole(role),
          const SizedBox(width: 8),
          IconButton(
            icon: const Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined),
                Positioned(
                  right: -2,
                  top: -2,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.danger,
                  ),
                ),
              ],
            ),
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
              backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
              child: user?.photoUrl == null
                  ? Text(
                      user != null && user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            tooltip: 'Mon profil',
            onPressed: () => context.go('/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex.clamp(0, navItems.length - 1),
              onDestinationSelected: (index) {
                final route = navItems[index].route;
                context.go(route);
              },
              labelType: NavigationRailLabelType.all,
              destinations: navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon ?? item.icon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex.clamp(0, navItems.length - 1),
              onTap: (index) {
                final route = navItems[index].route;
                context.go(route);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondaryLight,
              items: navItems.map((item) {
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon ?? item.icon),
                  label: item.label,
                );
              }).toList(),
            ),
    );
  }

  List<_NavigationItem> _getNavItems(UserRole role, dynamic user) {
    final items = <_NavigationItem>[
      const _NavigationItem(
        label: 'Accueil',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        route: '/dashboard',
      ),
      const _NavigationItem(
        label: 'Membres',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        route: '/members',
      ),
      const _NavigationItem(
        label: 'Cotisations',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        route: '/dues',
      ),
      const _NavigationItem(
        label: 'Trésorerie',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet,
        route: '/treasury',
      ),
      const _NavigationItem(
        label: 'Événements',
        icon: Icons.event_outlined,
        activeIcon: Icons.event,
        route: '/events',
      ),
    ];

    return items;
  }
}

class _NavigationItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String route;

  const _NavigationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.route,
  });
}
