import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/screens/admin_roles_screen.dart';
import '../../features/audit/screens/audit_log_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dues/screens/dues_list_screen.dart';
import '../../features/events/screens/events_list_screen.dart';
import '../../features/membership/providers/membership_provider.dart';
import '../../features/membership/screens/members_list_screen.dart';
import '../../features/membership/screens/membership_apply_screen.dart';
import '../../features/membership/screens/membership_status_screen.dart';
import '../../features/loans/screens/loans_screen.dart';
import '../../features/membership_fees/screens/membership_fee_screen.dart';
import '../../features/messaging/screens/conversations_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/posts/screens/posts_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/treasury/screens/treasury_dashboard_screen.dart';
import '../../features/user_profile/screens/profile_screen.dart';
import '../../features/about/screens/about_screen.dart';
import 'ajra_back_navigation.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);
  final isValidatedAndActive = ref.watch(isMemberValidatedAndActiveProvider);

  GoRoute _scopedRoute(
    String path,
    Widget Function(BuildContext context, GoRouterState state) builder,
  ) {
    return GoRoute(
      path: path,
      builder: (context, state) => AjraRouteBackScope(
        location: state.matchedLocation,
        child: builder(context, state),
      ),
    );
  }

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      _scopedRoute(
        '/login',
        (context, state) => const LoginScreen(),
      ),
      _scopedRoute(
        '/dashboard',
        (context, state) => const DashboardScreen(),
      ),
      _scopedRoute(
        '/members',
        (context, state) => const MembersListScreen(),
      ),
      _scopedRoute(
        '/membership-apply',
        (context, state) => const MembershipApplyScreen(),
      ),
      _scopedRoute(
        '/membership-status',
        (context, state) => const MembershipStatusScreen(),
      ),
      _scopedRoute(
        '/membership-fee',
        (context, state) => const MembershipFeeScreen(),
      ),
      _scopedRoute(
        '/dues',
        (context, state) => const DuesListScreen(),
      ),
      _scopedRoute(
        '/treasury',
        (context, state) => const TreasuryDashboardScreen(),
      ),
      _scopedRoute(
        '/loans',
        (context, state) => const LoansScreen(),
      ),
      _scopedRoute(
        '/events',
        (context, state) => const EventsListScreen(),
      ),
      _scopedRoute(
        '/posts',
        (context, state) => const PostsScreen(),
      ),
      _scopedRoute(
        '/notifications',
        (context, state) => const NotificationsScreen(),
      ),
      _scopedRoute(
        '/conversations',
        (context, state) => const ConversationsScreen(),
      ),
      _scopedRoute(
        '/chat/:convId',
        (context, state) {
          final convId = state.pathParameters['convId'] ?? '';
          return ChatScreen(
            conversationId: convId,
            otherParticipantName: 'Discussion',
          );
        },
      ),
      _scopedRoute(
        '/profile',
        (context, state) => const ProfileScreen(),
      ),
      _scopedRoute(
        '/about',
        (context, state) => const AboutScreen(),
      ),
      _scopedRoute(
        '/admin/roles',
        (context, state) => const AdminRolesScreen(),
      ),
      _scopedRoute(
        '/reports',
        (context, state) => const ReportsScreen(),
      ),
      _scopedRoute(
        '/audit',
        (context, state) => const AuditLogScreen(),
      ),
    ],
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isLoggedIn = user != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';
      final isPublicAbout = state.matchedLocation == '/about';

      if (isSplash) return null;

      if (!isLoggedIn && !isLoggingIn && !isPublicAbout) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return isValidatedAndActive ? '/dashboard' : '/membership-status';
      }

      // GARDE DE CONFIDENTIALITÉ AJRA :
      // Tout utilisateur connecté non validé / non adhérent (et non admin)
      // a accès à la page de suivi de sa demande, ses statuts AJRA/RPD et son profil.
      if (isLoggedIn && !isValidatedAndActive) {
        const allowedUnvalidatedRoutes = [
          '/membership-status',
          '/membership-apply',
          '/membership-fee',
          '/about',
          '/profile',
        ];
        if (!allowedUnvalidatedRoutes.contains(state.matchedLocation)) {
          return '/membership-status';
        }
        return null;
      }

      // Protection des routes admin
      if (state.matchedLocation.startsWith('/admin') && user != null && !user.isAdmin) {
        return '/dashboard';
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Erreur')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erreur : ${state.error ?? "Page introuvable"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Retour à la connexion'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
