import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/security/roles_and_permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/screens/notifications_screen.dart';
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
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderLight.withValues(alpha: 0.8), height: 1),
        ),
        leading: selectedIndex != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour à l\'accueil',
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    context.go('/dashboard');
                  }
                },
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  AppConstants.logoAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary,
                    alignment: Alignment.center,
                    child: const Text(
                      'AJRA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Jeunes de la Région Anosy • Maurice',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondaryLight,
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
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Messagerie & Groupes',
            onPressed: () => context.go('/conversations'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unreadNotifsCount = ref.watch(unreadNotificationsCountProvider);

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (unreadNotifsCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadNotifsCount > 9 ? '9+' : '$unreadNotifsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Notifications',
                onPressed: () => context.go('/notifications'),
              );
            },
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
              backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
              child: user?.photoUrl == null
                  ? Text(
                      user != null && user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderLight.withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex.clamp(0, navItems.length - 1),
                onDestinationSelected: (index) {
                  final route = navItems[index].route;
                  context.go(route);
                },
                destinations: navItems.map((item) {
                  return NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon ?? item.icon),
                    label: item.label,
                  );
                }).toList(),
              ),
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
