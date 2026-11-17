import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/cards/ajra_digital_member_card.dart';
import '../../../shared/widgets/cards/metric_card.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../auth/models/app_user.dart';
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
    final hasPasswordConfigured =
        user != null && (user.hasPassword || ref.read(authRepositoryProvider).isPasswordProviderLinked);

    return AppScaffold(
      selectedIndex: 0,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allMembersProvider);
              ref.invalidate(recentTransactionsProvider);
              ref.invalidate(allDuesProvider);
              ref.invalidate(userDuesProvider);
              ref.invalidate(eventsStreamProvider);
              ref.invalidate(postsStreamProvider);
              await ref.read(authRepositoryProvider).reloadUser();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Digital Member ID Card (Hero)
                  if (user != null)
                    AjraDigitalMemberCard(
                      user: user,
                      member: memberProfile,
                      onTap: () => context.go('/profile'),
                    ),
                  const SizedBox(height: 16),

                  // Prompt to configure password if not yet set
                  if (user != null && !hasPasswordConfigured) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lock_person_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connexion par identifiant & mot de passe',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Créez votre mot de passe dans Mon Profil pour vous connecter aussi avec ${user.email}.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => context.go('/profile'),
                            child: const Text('Créer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Role-specific Dashboard Content
                  if (role.isAdmin) ...[
                    _buildAdminDashboard(context, ref),
                  ] else if (role.isBureau && user != null) ...[
                    _buildBureauDashboard(context, ref, user),
                  ] else ...[
                    _buildMemberDashboard(context, ref, memberProfile),
                  ],

                  const SizedBox(height: 22),
                  _buildUpcomingEventSection(context, ref),

                  const SizedBox(height: 22),
                  _buildRecentPostsSection(context, ref),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildAdminDashboard(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);
    final allDuesAsync = ref.watch(allDuesProvider);
    final expiringAsync = ref.watch(expiringPassportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pilotage Exécutif & Indicateurs', Icons.analytics_outlined),
        const SizedBox(height: 12),

        // Priority Alerts Banner (Expiring Passports / Declared Dues to Verify)
        Builder(
          builder: (context) {
            final declaredCount = allDuesAsync.value
                    ?.where((d) => d.status == DueStatus.declared)
                    .length ??
                0;
            final expiringCount = expiringAsync.value?.length ?? 0;

            if (declaredCount == 0 && expiringCount == 0) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Actions prioritaires du Bureau',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (declaredCount > 0)
                          ActionChip(
                            avatar: const Icon(Icons.fact_check_outlined, size: 16, color: AppColors.primary),
                            label: Text('$declaredCount cotisation(s) à vérifier'),
                            onPressed: () => context.go('/dues'),
                          ),
                        if (expiringCount > 0)
                          ActionChip(
                            avatar: const Icon(Icons.badge_outlined, size: 16, color: AppColors.danger),
                            label: Text('$expiringCount passeport(s) expirant sous 90j'),
                            onPressed: () => context.go('/members'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),

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
                    subtitle: '${members.length} inscrits au total',
                    icon: Icons.people_alt_outlined,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/members'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Adhésions en attente',
                    value: '$pendingCount',
                    subtitle: pendingCount > 0 ? 'Examen requis' : 'Tout est à jour',
                    icon: Icons.pending_actions_outlined,
                    iconColor: pendingCount > 0 ? AppColors.warning : AppColors.success,
                    onTap: () => context.go('/members'),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
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
                    title: 'Écritures en attente',
                    value: '$pendingOps',
                    subtitle: pendingOps > 0 ? 'À valider' : 'Aucune en attente',
                    icon: Icons.hourglass_empty_rounded,
                    iconColor: pendingOps > 0 ? AppColors.warning : AppColors.success,
                    onTap: () => context.go('/treasury'),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 22),

        _buildSectionTitle('Modules & Administration', Icons.grid_view_rounded),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildActionChip(
              context,
              label: 'Utilisateurs & Rôles',
              icon: Icons.admin_panel_settings_outlined,
              route: '/admin/roles',
            ),
            _buildActionChip(
              context,
              label: 'Emprunts Solidaires',
              icon: Icons.handshake_outlined,
              route: '/loans',
            ),
            _buildActionChip(
              context,
              label: 'Rapports & Exports PDF/CSV',
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
              label: 'Messagerie & Groupes',
              icon: Icons.chat_outlined,
              route: '/conversations',
            ),
            _buildActionChip(
              context,
              label: 'Mon Profil & Mot de passe',
              icon: Icons.lock_person_outlined,
              route: '/profile',
            ),
            _buildActionChip(
              context,
              label: 'Statuts & Mises à jour',
              icon: Icons.gavel_rounded,
              route: '/about',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBureauDashboard(BuildContext context, WidgetRef ref, AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Espace Responsable du Bureau', Icons.workspace_premium_outlined),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
            _buildActionChip(
              context,
              label: 'Mon Profil & Mot de passe',
              icon: Icons.lock_person_outlined,
              route: '/profile',
            ),
            _buildActionChip(
              context,
              label: 'Statuts & Mises à jour',
              icon: Icons.gavel_rounded,
              route: '/about',
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
        // Member Status Card if incomplete or pending
        if (member == null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppColors.cardShadow,
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
          const SizedBox(height: 20),
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
                const Icon(Icons.hourglass_top, color: Color(0xFFB45309)),
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
          const SizedBox(height: 20),
        ],

        // Personal Dues & Regularity Progress Card
        _buildSectionTitle(
          'Mes Cotisations & Régularité',
          Icons.receipt_long_outlined,
          trailing: TextButton(
            onPressed: () => context.go('/dues'),
            child: const Text('Historique'),
          ),
        ),
        const SizedBox(height: 10),
        duesAsync.when(
          data: (dues) {
            final totalDuesCount = dues.length;
            final paidDuesCount = dues.where((d) => d.status == DueStatus.paid).length;
            final unpaidDues = dues.where((d) => d.status != DueStatus.paid).toList();

            int totalPaidCents = 0;
            for (final d in dues) {
              totalPaidCents += d.amountPaid.cents;
            }
            final totalPaidMoney = Money.fromCents(totalPaidCents);
            final progress = totalDuesCount > 0 ? (paidDuesCount / totalDuesCount) : 1.0;

            if (unpaidDues.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.successLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vous êtes 100 % à jour !',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                              Text(
                                totalDuesCount > 0
                                    ? '$paidDuesCount/$totalDuesCount mois réglés • Total versé : ${totalPaidMoney.toFormattedString()}'
                                    : 'Aucune cotisation en attente de règlement.',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            final firstUnpaid = unpaidDues.first;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                            'Reste à régler : ${firstUnpaid.remainingAmount.toFormattedString()}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      AjraButton(
                        label: 'Déclarer / Régler',
                        icon: Icons.payments_outlined,
                        height: 40,
                        onPressed: () => context.go('/dues'),
                      ),
                    ],
                  ),
                  if (totalDuesCount > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Régularité : $paidDuesCount / $totalDuesCount mois validés',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                        ),
                        Text(
                          'Cumul versé : ${totalPaidMoney.toFormattedString()}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Services & Espace Associatif', Icons.apps_rounded),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildActionChip(
              context,
              label: 'Événements & Sorties',
              icon: Icons.event_outlined,
              route: '/events',
            ),
            _buildActionChip(
              context,
              label: 'Emprunts Solidaires',
              icon: Icons.handshake_outlined,
              route: '/loans',
            ),
            _buildActionChip(
              context,
              label: 'Messagerie & Groupes',
              icon: Icons.chat_bubble_outline,
              route: '/conversations',
            ),
            _buildActionChip(
              context,
              label: 'Actualités officielles',
              icon: Icons.newspaper_outlined,
              route: '/posts',
            ),
            _buildActionChip(
              context,
              label: 'Droit d\'adhésion',
              icon: Icons.payments_outlined,
              route: '/membership-fee',
            ),
            _buildActionChip(
              context,
              label: 'Mon Profil & Mot de passe',
              icon: Icons.lock_person_outlined,
              route: '/profile',
            ),
            _buildActionChip(
              context,
              label: 'Statuts & Mises à jour',
              icon: Icons.gavel_rounded,
              route: '/about',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingEventSection(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final nextEvent = events.first;
        final dateStr = DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(nextEvent.startDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Prochaine Activité / Sortie AJRA',
              Icons.event_available_outlined,
              trailing: TextButton(
                onPressed: () => context.go('/events'),
                child: const Text('Voir tout'),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.go('/events'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppColors.oceanicGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.celebration_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextEvent.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '📍 ${nextEvent.location} • 🗓 $dateStr',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                          if (nextEvent.participationFee != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'PAF : ${nextEvent.participationFee!.toFormattedString()} / personne',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondaryDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedLight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String route,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.9)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPostsSection(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Communiqués & Actualités',
          Icons.campaign_outlined,
          trailing: TextButton(
            onPressed: () => context.go('/posts'),
            child: const Text('Tout voir'),
          ),
        ),
        const SizedBox(height: 8),
        postsAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.textSecondaryLight),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aucune publication officielle pour le moment.',
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
                final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(post.publishedAt);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.14),
                      child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      post.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(
                          post.content,
                          style: const TextStyle(fontSize: 12.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Publié le $dateStr par ${post.authorName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMutedLight),
                    onTap: () => context.go('/posts'),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
