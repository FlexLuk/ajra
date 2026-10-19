import 'package:flutter/material.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.fromMembershipStatus(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.active:
        return const StatusBadge(
          label: 'Active',
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
          icon: Icons.check_circle_outline,
        );
      case MembershipStatus.pending:
        return const StatusBadge(
          label: 'En attente',
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
          icon: Icons.hourglass_top,
        );
      case MembershipStatus.rejected:
        return const StatusBadge(
          label: 'Rejetée',
          backgroundColor: AppColors.dangerLight,
          textColor: AppColors.danger,
          icon: Icons.cancel_outlined,
        );
      case MembershipStatus.suspended:
        return const StatusBadge(
          label: 'Suspendue',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF475569),
          icon: Icons.pause_circle_outline,
        );
      case MembershipStatus.terminated:
        return const StatusBadge(
          label: 'Terminée',
          backgroundColor: Color(0xFFE2E8F0),
          textColor: Color(0xFF64748B),
          icon: Icons.archive_outlined,
        );
    }
  }

  factory StatusBadge.fromRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const StatusBadge(
          label: 'Administrateur',
          backgroundColor: Color(0xFFEFF6FF),
          textColor: AppColors.primary,
          icon: Icons.shield,
        );
      case UserRole.bureau:
        return const StatusBadge(
          label: 'Membre du Bureau',
          backgroundColor: Color(0xFFCCFBF1),
          textColor: AppColors.secondaryDark,
          icon: Icons.badge,
        );
      case UserRole.member:
        return const StatusBadge(
          label: 'Membre',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF475569),
          icon: Icons.person_outline,
        );
    }
  }

  factory StatusBadge.paymentStatus({
    required bool isVerified,
    required bool isDeclared,
    required bool isRejected,
  }) {
    if (isVerified) {
      return const StatusBadge(
        label: 'Vérifié & Payé',
        backgroundColor: AppColors.successLight,
        textColor: AppColors.success,
        icon: Icons.verified,
      );
    } else if (isRejected) {
      return const StatusBadge(
        label: 'Paiement rejeté',
        backgroundColor: AppColors.dangerLight,
        textColor: AppColors.danger,
        icon: Icons.highlight_off,
      );
    } else if (isDeclared) {
      return const StatusBadge(
        label: 'En attente de vérification',
        backgroundColor: AppColors.warningLight,
        textColor: AppColors.warning,
        icon: Icons.schedule,
      );
    } else {
      return const StatusBadge(
        label: 'Non payé',
        backgroundColor: AppColors.dangerLight,
        textColor: AppColors.danger,
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
