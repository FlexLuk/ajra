import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/models/app_user.dart';
import '../../../features/membership/models/member_profile.dart';

class AjraDigitalMemberCard extends StatelessWidget {
  final AppUser user;
  final MemberProfile? member;
  final VoidCallback? onTap;
  final bool compact;

  const AjraDigitalMemberCard({
    super.key,
    required this.user,
    this.member,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = (member != null && member!.fullName.trim().isNotEmpty)
        ? member!.fullName
        : (user.displayName.trim().isNotEmpty ? user.displayName : 'Membre AJRA');
    final matricule = member?.memberNumber ?? 'AJRA-${DateTime.now().year}-MEMBRE';
    final isActive = user.isAdmin || (member != null && member!.status == MembershipStatus.active);
    final statusLabel = isActive
        ? 'MEMBRE VÉRIFIÉ'
        : (member?.status.label.toUpperCase() ?? 'DOSSIER À COMPLÉTER');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF071424),
                Color(0xFF0F2C4A),
                Color(0xFF0B3A4F),
                Color(0xFF084F59),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.2,
            ),
            boxShadow: AppColors.memberCardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Subtle decorative circles
                Positioned(
                  right: -35,
                  top: -35,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  left: -25,
                  bottom: -45,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryLight.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 18 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header: Logo + Association Title + Verified Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                AppConstants.logoAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.groups_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CARTE DE MEMBRE OFFICIELLE',
                                  style: TextStyle(
                                    color: Color(0xFFFCD34D),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'AJRA • Région Anosy (Île Maurice)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.22)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFFBBF24),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Icons.verified_rounded : Icons.schedule_rounded,
                                  size: 13,
                                  color: isActive
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFFFDE68A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF3C7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 16 : 20),

                      // Middle: Member Identity & Matricule
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFCD34D).withValues(alpha: 0.7),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: compact ? 24 : 28,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              backgroundImage:
                                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                              child: user.photoUrl == null
                                  ? Text(
                                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 17.5 : 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Text(
                                        matricule,
                                        style: const TextStyle(
                                          color: Color(0xFFFDE68A),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        user.role.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: compact ? 14 : 18),
                      Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
                      const SizedBox(height: 12),

                      // Bottom Metadata Strip
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _buildCardMeta(
                            label: 'STATUT SÉJOUR',
                            value: member?.permitType.label ?? 'Membre AJRA',
                          ),
                          _buildCardMeta(
                            label: 'PASSEPORT',
                            value: member != null && member!.passportNumber.isNotEmpty
                                ? member!.maskedPassportNumber
                                : 'Confidentiel',
                          ),
                          _buildCardMeta(
                            label: 'CONTACT',
                            value: member != null && member!.phone.trim().isNotEmpty
                                ? member!.phone
                                : user.email,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardMeta({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
