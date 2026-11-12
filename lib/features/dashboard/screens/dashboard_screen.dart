import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/cards/metric_card.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dues/models/monthly_due.dart';
import '../../dues/screens/dues_list_screen.dart';
import '../../events/screens/events_list_screen.dart';
import '../../membership/models/member_profile.dart';
import '../../membership/providers/membership_provider.dart';
import '../../posts/screens/posts_screen.dart';
import '../../treasury/screens/treasury_dashboard_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final memberProfile = ref.watch(currentMemberProfileProvider).value;
    final role = user?.role ?? UserRole.member;

    return AppScaffold(
      selectedIndex: 0,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner
                _buildWelcomeBanner(context, user, memberProfile),
                const SizedBox(height: 20),

                // If role is ADMIN
                if (role.isAdmin) ...[
                  _buildAdminDashboard(context, ref),
                ] else if (role.isBureau) ...[
                  _buildBureauDashboard(context, ref, user!),
                ] else ...[
                  _buildMemberDashboard(context, ref, memberProfile),
                ],

                const SizedBox(height: 24),
                _buildRecentPostsSection(context, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, dynamic user, MemberProfile? member) {
    final displayName = user?.displayName ?? 'Membre';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              backgroundImage: user?.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user?.photoUrl == null
                  ? Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $displayName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    member != null
                        ? 'Matricule : ${member.memberNumber} • ${member.status.label}'
                        : 'Espace Membre Officiel AJRA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                AppConstants.logoAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.groups,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);
    final duesAsync = ref.watch(allDuesProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vue d\'ensemble Administrateur',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Metrics Grid
        membersAsync.when(
          data: (members) {
            final activeCount = members.where((m) => m.isActive).length;
            final pendingCount = members.where((m) => m.isPending).length;

            return Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Membres Actifs',
                    value: '$activeCount',
                    subtitle: '$pendingCount en attente',
                    icon: Icons.people_alt_outlined,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/members'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Demandes à valider',
                    value: '$pendingCount',
                    subtitle: 'Examen requis',
                    icon: Icons.pending_actions_outlined,
                    iconColor: AppColors.warning,
                    onTap: () => context.go('/members'),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),

        txsAsync.when(
          data: (txs) {
            final validatedTxs = txs.where((t) => t.status == TransactionStatus.validated);
            int inc = 0;
            int exp = 0;
            for (final t in validatedTxs) {
              if (t.type == TransactionType.income) inc += t.amount.cents;
              if (t.type == TransactionType.expense) exp += t.amount.cents;
            }
            final balance = Money.fromCents(inc - exp);
            final pendingOps = txs.where((t) => t.status == TransactionStatus.pending).length;

            return Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Solde Trésorerie',
                    value: balance.toFormattedString(),
                    subtitle: 'Total net validé',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.secondary,
                    onTap: () => context.go('/treasury'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Opérations en attente',
                    value: '$pendingOps',
                    subtitle: 'À vérifier',
                    icon: Icons.hourglass_empty_rounded,
                    iconColor: AppColors.warning,
                    onTap: () => context.go('/treasury'),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),

        // Quick Navigation Grid
        const Text(
          'Raccourcis de gestion',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionChip(
              context,
              label: 'Gestion Utilisateurs & Rôles',
              icon: Icons.admin_panel_settings_outlined,
              route: '/admin/roles',
            ),
            _buildActionChip(
              context,
              label: 'Rapports & Exports',
              icon: Icons.picture_as_pdf_outlined,
              route: '/reports',
            ),
            _buildActionChip(
              context,
              label: 'Journal d\'Audit',
              icon: Icons.history_edu_outlined,
              route: '/audit',
            ),
            _buildActionChip(
              context,
              label: 'Fil d\'actualités',
              icon: Icons.newspaper_outlined,
              route: '/posts',
            ),
            _buildActionChip(
              context,
              label: 'Emprunts des Membres',
              icon: Icons.handshake_outlined,
              route: '/loans',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBureauDashboard(BuildContext context, WidgetRef ref, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Espace Bureau AJRA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (user.isAdmin)
              _buildActionChip(
                context,
                label: 'Rôles & Utilisateurs',
                icon: Icons.admin_panel_settings_outlined,
                route: '/admin/roles',
              ),
            if (user.canReviewMembership)
              _buildActionChip(
                context,
                label: 'Examiner les adhésions',
                icon: Icons.fact_check_outlined,
                route: '/members',
              ),
            if (user.canVerifyPayments)
              _buildActionChip(
                context,
                label: 'Vérification des cotisations',
                icon: Icons.rule_folder_outlined,
                route: '/dues',
              ),
            if (user.canViewFinanceReports)
              _buildActionChip(
                context,
                label: 'Consulter la trésorerie',
                icon: Icons.analytics_outlined,
                route: '/treasury',
              ),
            if (user.canManageEvents)
              _buildActionChip(
                context,
                label: 'Gérer les événements',
                icon: Icons.event_available_outlined,
                route: '/events',
              ),
            _buildActionChip(
              context,
              label: 'Messagerie',
              icon: Icons.chat_outlined,
              route: '/conversations',
            ),
            _buildActionChip(
              context,
              label: 'Publier actualité',
              icon: Icons.post_add_outlined,
              route: '/posts',
            ),
            _buildActionChip(
              context,
              label: 'Emprunts des Membres',
              icon: Icons.handshake_outlined,
              route: '/loans',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberDashboard(BuildContext context, WidgetRef ref, MemberProfile? member) {
    final duesAsync = ref.watch(userDuesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Member Status Card
        if (member == null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Complétez votre dossier d\'adhésion',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pour devenir membre actif de l\'AJRA et participer aux activités, veuillez soumettre votre dossier administratif.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 14),
                AjraButton(
                  label: 'Faire ma demande d\'adhésion',
                  icon: Icons.assignment_turned_in_outlined,
                  onPressed: () => context.go('/membership-apply'),
                ),
              ],
            ),
          ),
        ] else if (member.isPending) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adhésion en cours d\'examen',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Dossier ${member.memberNumber} déposé le ${member.appliedAt.day}/${member.appliedAt.month}/${member.appliedAt.year}.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/membership-status'),
                  child: const Text('Détails'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Personal Dues Quick Look
        const Text(
          'Mes Cotisations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        duesAsync.when(
          data: (dues) {
            final unpaidDues = dues.where((d) => d.status != DueStatus.paid).toList();

            if (unpaidDues.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous êtes parfaitement à jour dans vos cotisations !',
                        style: TextStyle(
                            color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }

            final firstUnpaid = unpaidDues.first;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Échéance : ${firstUnpaid.periodLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reste à payer : ${firstUnpaid.remainingAmount.toFormattedString()}',
                        style: const TextStyle(fontSize: 13, color: AppColors.primary),
                      ),
                    ],
                  ),
                  AjraButton(
                    label: 'Régler',
                    height: 38,
                    onPressed: () => context.go('/dues'),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),
        // Member Navigation Links
        const Text(
          'Accès direct',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionChip(
              context,
              label: 'Événements & Activités',
              icon: Icons.event_outlined,
              route: '/events',
            ),
            _buildActionChip(
              context,
              label: 'Actualités officielles',
              icon: Icons.newspaper_outlined,
              route: '/posts',
            ),
            _buildActionChip(
              context,
              label: 'Messagerie',
              icon: Icons.chat_bubble_outline,
              route: '/conversations',
            ),
            _buildActionChip(
              context,
              label: 'Droit d\'adhésion',
              icon: Icons.payments_outlined,
              route: '/membership-fee',
            ),
            _buildActionChip(
              context,
              label: 'Emprunts des Membres',
              icon: Icons.handshake_outlined,
              route: '/loans',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPostsSection(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.campaign_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Publications & Actualités',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go('/posts'),
              child: const Text('Tout voir'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        postsAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.textSecondaryLight),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aucune publication pour le moment.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              );
            }

            final previewPosts = posts.take(2).toList();
            return Column(
              children: previewPosts.map((post) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                      child: const Icon(Icons.campaign, color: AppColors.primary, size: 18),
                    ),
                    title: Text(
                      post.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      post.content,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMutedLight),
                    onTap: () => context.go('/posts'),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
