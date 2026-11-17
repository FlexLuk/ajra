import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/membership_provider.dart';
import 'member_detail_screen.dart';

class MembersListScreen extends ConsumerWidget {
  const MembersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);
    final expiringAsync = ref.watch(expiringPassportsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentMember = ref.watch(currentMemberProfileProvider).value;

    final selectedStatus = ref.watch(memberStatusFilterProvider);
    final selectedPermit = ref.watch(memberPermitFilterProvider);

    final canManage = currentUser != null &&
        (currentUser.isAdmin || currentUser.canReviewMembership);

    return AppScaffold(
      selectedIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          leading: const AjraBackButton(fallbackRoute: '/dashboard'),
          title: const Text('Membres de l\'association'),
          actions: [
            if (currentUser != null && currentUser.isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                tooltip: 'Gestion des rôles & utilisateurs',
                onPressed: () => context.go('/admin/roles'),
              ),
            if (canManage)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Exporter la liste',
                onPressed: () => context.go('/reports'),
              ),
          ],
        ),
        body: Column(
          children: [
            // Summary Strip of Association Membership
            membersAsync.when(
              data: (members) {
                final activeCount = members.where((m) => m.isActive).length;
                final pendingCount = members.where((m) => m.isPending).length;
                final workerCount =
                    members.where((m) => m.permitType == PermitType.worker).length;
                final studentCount =
                    members.where((m) => m.permitType == PermitType.student).length;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Effectif : ${members.length} membre(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$activeCount actif(s) • $pendingCount en attente • $workerCount trav. / $studentCount étud.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (val) {
                  ref.read(memberSearchQueryProvider.notifier).state = val;
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, e-mail, matricule...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ref.watch(memberSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            ref.read(memberSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Filters Scrollable Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous statuts'),
                    selected: selectedStatus == null,
                    onSelected: (_) {
                      ref.read(memberStatusFilterProvider.notifier).state = null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('En attente'),
                    selected: selectedStatus == MembershipStatus.pending,
                    onSelected: (val) {
                      ref.read(memberStatusFilterProvider.notifier).state =
                          val ? MembershipStatus.pending : null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Actifs'),
                    selected: selectedStatus == MembershipStatus.active,
                    onSelected: (val) {
                      ref.read(memberStatusFilterProvider.notifier).state =
                          val ? MembershipStatus.active : null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Rejetés'),
                    selected: selectedStatus == MembershipStatus.rejected,
                    onSelected: (val) {
                      ref.read(memberStatusFilterProvider.notifier).state =
                          val ? MembershipStatus.rejected : null;
                    },
                  ),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 24, color: AppColors.borderLight),
                  const SizedBox(width: 16),
                  FilterChip(
                    label: const Text('Travailleurs'),
                    selected: selectedPermit == PermitType.worker,
                    onSelected: (val) {
                      ref.read(memberPermitFilterProvider.notifier).state =
                          val ? PermitType.worker : null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Étudiants'),
                    selected: selectedPermit == PermitType.student,
                    onSelected: (val) {
                      ref.read(memberPermitFilterProvider.notifier).state =
                          val ? PermitType.student : null;
                    },
                  ),
                ],
              ),
            ),

            // Passport Expiry Warning Banner (for managers)
            if (canManage)
              expiringAsync.when(
                data: (expiring) {
                  if (expiring.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${expiring.length} membre(s) ont un passeport expirant sous 90 jours.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

            // Members List
            Expanded(
              child: membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.people_outline,
                      title: 'Aucun membre trouvé',
                      message: 'Aucun dossier ne correspond aux critères de recherche.',
                      actionLabel: currentUser?.isAdmin == true
                          ? 'Gérer les utilisateurs & Rôles'
                          : (currentMember == null ? 'Faire une demande d\'adhésion' : null),
                      onAction: () => currentUser?.isAdmin == true
                          ? context.go('/admin/roles')
                          : context.go('/membership-apply'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final isCurrentUser = currentUser?.uid == m.userId;

                      return Card(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                            backgroundImage:
                                m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
                            child: m.photoUrl == null
                                ? Text(
                                    m.firstName.isNotEmpty ? m.firstName[0].toUpperCase() : 'M',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (isCurrentUser)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Moi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${m.memberNumber} • ${m.permitType.label}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  StatusBadge.fromMembershipStatus(m.status),
                                  if (m.isPassportExpiringSoon() && canManage) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppColors.warning,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: (canManage || isCurrentUser)
                              ? const Icon(Icons.chevron_right, color: AppColors.textMutedLight)
                              : const Icon(Icons.lock_outline, size: 16, color: AppColors.textMutedLight),
                          onTap: () {
                            if (!canManage && !isCurrentUser) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Accès restreint : Seuls les membres du bureau et l\'administrateur peuvent consulter les informations détaillées des membres.',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MemberDetailScreen(member: m),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingStateView(message: 'Chargement des membres...'),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.refresh(allMembersProvider),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: currentMember == null
            ? FloatingActionButton.extended(
                onPressed: () => context.go('/membership-apply'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Faire une adhésion'),
                backgroundColor: AppColors.primary,
              )
            : (currentUser != null && currentUser.isAdmin
                ? FloatingActionButton.extended(
                    onPressed: () => context.go('/admin/roles'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Gérer les rôles'),
                    backgroundColor: AppColors.primary,
                  )
                : null),
      ),
    );
  }
}
