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

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);
  final isValidatedAndActive = ref.watch(isMemberValidatedAndActiveProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/members',
        builder: (context, state) => const MembersListScreen(),
      ),
      GoRoute(
        path: '/membership-apply',
        builder: (context, state) => const MembershipApplyScreen(),
      ),
      GoRoute(
        path: '/membership-status',
        builder: (context, state) => const MembershipStatusScreen(),
      ),
      GoRoute(
        path: '/membership-fee',
        builder: (context, state) => const MembershipFeeScreen(),
      ),
      GoRoute(
        path: '/dues',
        builder: (context, state) => const DuesListScreen(),
      ),
      GoRoute(
        path: '/treasury',
        builder: (context, state) => const TreasuryDashboardScreen(),
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) => const LoansScreen(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsListScreen(),
      ),
      GoRoute(
        path: '/posts',
        builder: (context, state) => const PostsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/chat/:convId',
        builder: (context, state) {
          final convId = state.pathParameters['convId'] ?? '';
          return ChatScreen(
            conversationId: convId,
            otherParticipantName: 'Discussion',
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (context, state) => const AdminRolesScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const AuditLogScreen(),
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
