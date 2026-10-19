import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membership/providers/membership_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de votre compte AJRA ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suppression du compte (RGPD)'),
        content: const Text(
          'Attention : Conformément au RGPD et à la protection des données, vos identifiants d\'accès seront supprimés et votre compte sera désactivé. Vos opérations comptables historiques resteront archivées anonymement pour la conformité légale de l\'association. Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer la suppression'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount();
        if (mounted) context.go('/login');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final member = ref.watch(currentMemberProfileProvider).value;
    final role = user?.role ?? UserRole.member;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil & Paramètres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            tooltip: 'Déconnexion',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                      backgroundImage:
                          user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                      child: user?.photoUrl == null
                          ? Text(
                              user != null && user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Membre',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              StatusBadge.fromRole(role),
                              if (member != null) ...[
                                const SizedBox(width: 8),
                                StatusBadge.fromMembershipStatus(member.status),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Membership Card
              if (member != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dossier d\'adhésion',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),
                      _buildInfoRow('Matricule AJRA', member.memberNumber),
                      _buildInfoRow('Téléphone', member.phone),
                      _buildInfoRow('Adresse', member.residentialAddress),
                      _buildInfoRow('Statut de séjour', member.permitType.label),
                      _buildInfoRow('Numéro de passeport', member.maskedPassportNumber),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/membership-status'),
                        child: const Text('Voir l\'état détaillé de ma demande'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Role & Permissions info
              if (role.isBureau || role.isAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Permissions attribuées',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),
                      if (role.isAdmin)
                        const Text(
                          'En tant qu\'Administrateur, vous disposez de l\'accès complet à tous les modules, approbations financières et configurations.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                        )
                      else ...[
                        if (user != null && user.permissions.isNotEmpty)
                          ...user.permissions.map((p) {
                            final label = AppPermissions.labels[p] ?? p;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 16, color: AppColors.secondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(label, style: const TextStyle(fontSize: 12.5))),
                                ],
                              ),
                            );
                          })
                        else
                          const Text(
                            'Aucune permission financière ou d\'examen spécifique ne vous a encore été attribuée par l\'administrateur.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Danger Zone: Account Deletion
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.dangerLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestion des données personnelles',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vous pouvez demander la désactivation de votre compte et la purge de vos données d\'accès conformément à la politique de confidentialité de l\'AJRA.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 14),
                    AjraButton(
                      label: 'Supprimer mon compte',
                      icon: Icons.delete_forever_outlined,
                      variant: AjraButtonVariant.danger,
                      height: 40,
                      onPressed: _handleDeleteAccount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
