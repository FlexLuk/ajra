import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../providers/membership_provider.dart';

class MembershipStatusScreen extends ConsumerWidget {
  const MembershipStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(currentMemberProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statut de mon adhésion'),
      ),
      body: SafeArea(
        child: memberAsync.when(
          data: (member) {
            if (member == null) {
              return EmptyStateView(
                icon: Icons.assignment_ind_outlined,
                title: 'Aucune demande d\'adhésion',
                message: 'Vous n\'avez pas encore soumis votre dossier d\'adhésion à l\'AJRA.',
                actionLabel: 'Remplir ma demande',
                onAction: () => context.go('/membership-apply'),
              );
            }

            final dateFormat = DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Header Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: member.status == MembershipStatus.active
                                  ? AppColors.successLight
                                  : member.status == MembershipStatus.pending
                                      ? AppColors.warningLight
                                      : AppColors.dangerLight,
                              child: Icon(
                                member.status == MembershipStatus.active
                                    ? Icons.verified_user_rounded
                                    : member.status == MembershipStatus.pending
                                        ? Icons.hourglass_top_rounded
                                        : Icons.cancel_rounded,
                                size: 40,
                                color: member.status == MembershipStatus.active
                                    ? AppColors.success
                                    : member.status == MembershipStatus.pending
                                        ? AppColors.warning
                                        : AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              member.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Matricule : ${member.memberNumber}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StatusBadge.fromMembershipStatus(member.status),
                            const SizedBox(height: 20),
                            Text(
                              _getStatusDescription(member.status),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight,
                                height: 1.4,
                              ),
                            ),
                            if (member.reviewNotes != null &&
                                member.reviewNotes!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Remarque du bureau :',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member.reviewNotes!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions Card
                      if (member.status == MembershipStatus.active) ...[
                        AjraButton(
                          label: 'Consulter mon droit d\'adhésion',
                          icon: Icons.payments_outlined,
                          onPressed: () => context.go('/membership-fee'),
                          variant: AjraButtonVariant.primary,
                        ),
                        const SizedBox(height: 12),
                        AjraButton(
                          label: 'Consulter mes cotisations',
                          icon: Icons.receipt_long_outlined,
                          onPressed: () => context.go('/dues'),
                          variant: AjraButtonVariant.outline,
                        ),
                      ] else if (member.status == MembershipStatus.rejected) ...[
                        AjraButton(
                          label: 'Soumettre une nouvelle demande',
                          icon: Icons.refresh,
                          onPressed: () => context.go('/membership-apply'),
                          variant: AjraButtonVariant.primary,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Timeline details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Historique du dossier',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 20),
                            _buildTimelineItem(
                              'Demande soumise',
                              dateFormat.format(member.appliedAt),
                              Icons.send,
                              AppColors.primary,
                            ),
                            if (member.approvedAt != null)
                              _buildTimelineItem(
                                'Adhésion validée',
                                dateFormat.format(member.approvedAt!),
                                Icons.check_circle,
                                AppColors.success,
                              ),
                            if (member.rejectedAt != null)
                              _buildTimelineItem(
                                'Demande rejetée',
                                dateFormat.format(member.rejectedAt!),
                                Icons.cancel,
                                AppColors.danger,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const LoadingStateView(message: 'Vérification du statut...'),
          error: (e, _) => EmptyStateView(
            icon: Icons.error_outline,
            title: 'Erreur',
            message: e.toString(),
          ),
        ),
      ),
    );
  }

  String _getStatusDescription(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.pending:
        return 'Votre dossier a bien été transmis. Un membre habilité du bureau AJRA examine actuellement votre demande. Vous recevrez une notification dès que la décision sera rendue.';
      case MembershipStatus.active:
        return 'Félicitations ! Votre adhésion a été validée. Vous pouvez désormais régler votre droit d\'adhésion et participer pleinement à toutes les activités.';
      case MembershipStatus.rejected:
        return 'Votre demande d\'adhésion a été rejetée par le bureau. Vous pouvez corriger votre dossier et le soumettre à nouveau.';
      case MembershipStatus.suspended:
        return 'Votre adhésion est temporairement suspendue. Veuillez contacter l\'administration pour régulariser votre situation.';
      case MembershipStatus.terminated:
        return 'Votre adhésion est clôturée.';
    }
  }

  Widget _buildTimelineItem(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
