import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/member_profile.dart';
import '../providers/membership_provider.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  final MemberProfile member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  bool _isProcessing = false;
  late MemberProfile _member;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

  Future<void> _handleReview(bool approve) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (_member.userId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Règle de sécurité : Vous ne pouvez pas statuer sur votre propre dossier.'),
        ),
      );
      return;
    }

    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Valider l\'adhésion' : 'Rejeter l\'adhésion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                ? 'Confirmez-vous l\'approbation de l\'adhésion de ${_member.fullName} ?'
                : 'Indiquez le motif de rejet pour la notification au demandeur :',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                hintText: 'Commentaire ou motif...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.success : AppColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Confirmer l\'adhésion' : 'Rejeter la demande'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(membershipRepositoryProvider);
      await repo.reviewApplication(
        memberId: _member.id,
        reviewerUserId: currentUser.uid,
        reviewerName: currentUser.displayName,
        reviewerRole: currentUser.role.code,
        approve: approve,
        reviewNotes: notesController.text.trim(),
      );

      final updated = await repo.getMemberProfile(_member.userId);
      if (updated != null && mounted) {
        setState(() => _member = updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: approve ? AppColors.success : AppColors.danger,
            content: Text(
              approve
                ? 'Adhésion validée avec succès.'
                : 'La demande a été rejetée.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Erreur : ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openAdminStatusDialog() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) return;

    MembershipStatus selectedStatus = _member.status;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Statut : ${_member.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modifier le statut officiel du membre :'),
              const SizedBox(height: 12),
              DropdownButtonFormField<MembershipStatus>(
                initialValue: selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Statut du membre'),
                items: MembershipStatus.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.label, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => selectedStatus = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Motif / Remarques administratives',
                  hintText: 'ex: Validation directe par l\'administration...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer le statut'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        final repo = ref.read(membershipRepositoryProvider);
        await repo.updateMemberStatus(
          memberId: _member.id,
          newStatus: selectedStatus,
          adminUserId: currentUser.uid,
          adminName: currentUser.displayName,
          notes: notesController.text.trim(),
        );

        final updated = await repo.getMemberProfile(_member.userId);
        if (updated != null && mounted) {
          setState(() => _member = updated);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Statut du membre mis à jour avec succès.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('Erreur : ${e.toString()}'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDeleteMemberAccount() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) return;

    if (_member.userId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas supprimer votre propre compte.')),
      );
      return;
    }

    if (_member.email.toLowerCase().trim() == 'heriniaina.luk@gmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer le compte du super-administrateur.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Suppression irréversible du compte',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmez-vous la suppression intégrale du compte et de toutes les données de ${_member.fullName} (${_member.memberNumber}) ?',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cette opération efface immédiatement :\n'
              '• Le compte d\'accès et fiche utilisateur\n'
              '• Le profil membre et numéro matricule\n'
              '• Les paiements d\'adhésion, cotisations et prêts\n'
              '• Les documents (passeport, photo, justificatifs)\n'
              '• L\'historique des notifications et inscriptions',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Supprimer définitivement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(authRepositoryProvider).deleteUserAccountAndDataByAdmin(
          targetUserId: _member.userId,
          targetEmail: _member.email,
          adminUserId: currentUser.uid,
          adminName: currentUser.displayName,
        );

        ref.invalidate(allMembersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Le compte et les données de ${_member.fullName} ont été supprimés.'),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('Erreur : ${e.toString()}'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final canView = currentUser != null &&
        (currentUser.isAdmin || currentUser.canReviewMembership || currentUser.uid == _member.userId);

    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Retour',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/members');
              }
            },
          ),
          title: const Text('Accès restreint'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: AppColors.textSecondaryLight),
                const SizedBox(height: 16),
                const Text(
                  'Accès confidentiel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seuls les membres du bureau et l\'administrateur sont autorisés à consulter les informations personnelles et administratives des membres.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      context.go('/members');
                    }
                  },
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isPrivileged =
        currentUser.isAdmin || currentUser.canReviewMembership || currentUser.uid == _member.userId;
    final canReview =
        (currentUser.isAdmin || (currentUser.canReviewMembership && currentUser.uid != _member.userId)) &&
        _member.isPending;

    final dateFormat = DateFormat('dd MMMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/members');
            }
          },
        ),
        title: Text(_member.fullName),
        actions: [
          if (currentUser.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note_outlined),
              tooltip: 'Modifier le statut officiel',
              onPressed: _openAdminStatusDialog,
            ),
          if (currentUser.isAdmin &&
              _member.userId != currentUser.uid &&
              _member.email.toLowerCase().trim() != 'heriniaina.luk@gmail.com')
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
              tooltip: 'Supprimer ce compte et toutes ses données',
              onPressed: _handleDeleteMemberAccount,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
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
                    radius: 32,
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    backgroundImage:
                        _member.photoUrl != null ? NetworkImage(_member.photoUrl!) : null,
                    child: _member.photoUrl == null
                        ? Text(
                            _member.firstName.isNotEmpty
                                ? _member.firstName[0].toUpperCase()
                                : 'M',
                            style: const TextStyle(
                              fontSize: 24,
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
                          _member.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matricule : ${_member.memberNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusBadge.fromMembershipStatus(_member.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Passport Expiry Alert
            if (_member.isPassportExpired) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.danger),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Attention : Le passeport de ce membre est expiré !',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_member.isPassportExpiringSoon()) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Alerte : Le passeport expire dans ${_member.daysUntilPassportExpires} jours (${dateFormat.format(_member.passportExpiryDate)})',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Card Informations Personnelles
            _buildSectionCard(
              title: 'Informations personnelles',
              icon: Icons.person_outline,
              items: [
                _buildInfoRow('Prénom', _member.firstName),
                _buildInfoRow('Nom', _member.lastName),
                _buildInfoRow('Date de naissance', dateFormat.format(_member.birthDate)),
                _buildInfoRow('Téléphone', _member.phone),
                _buildInfoRow('E-mail', _member.email),
                _buildInfoRow('Résidence à Maurice', _member.residentialAddress),
                _buildInfoRow('Date de la demande', dateFormat.format(_member.appliedAt)),
              ],
            ),
            const SizedBox(height: 16),

            // Card Informations Administratives & Permis
            _buildSectionCard(
              title: 'Informations administratives',
              icon: Icons.badge_outlined,
              items: [
                _buildInfoRow(
                  'Numéro de passeport',
                  isPrivileged ? _member.passportNumber : _member.maskedPassportNumber,
                ),
                _buildInfoRow('Date de délivrance', dateFormat.format(_member.passportIssueDate)),
                _buildInfoRow('Date d\'expiration', dateFormat.format(_member.passportExpiryDate)),
                _buildInfoRow('Statut de séjour', _member.permitType.label),
                if (_member.permitType == PermitType.worker) ...[
                  _buildInfoRow('Profession', _member.jobTitle ?? 'Non renseigné'),
                  _buildInfoRow('Employeur', _member.employer ?? 'Non renseigné'),
                ] else ...[
                  _buildInfoRow('Domaine d\'études', _member.fieldOfStudy ?? 'Non renseigné'),
                  _buildInfoRow('Établissement', _member.institution ?? 'Non renseigné'),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Statuts de l'AJRA & RPD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Statuts de l\'AJRA & RPD',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Les 15 statuts officiels fondateurs et la charte de protection des données régissent l\'association et l\'ensemble de ses membres.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Consulter les 15 Statuts & RPD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => context.go('/about'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions de validation pour le bureau / admin
            if (canReview) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Décision du Bureau',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'En tant que responsable autorisé, examinez ce dossier avant de rendre votre décision.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AjraButton(
                            label: 'Rejeter',
                            icon: Icons.close,
                            variant: AjraButtonVariant.danger,
                            isLoading: _isProcessing,
                            onPressed: () => _handleReview(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AjraButton(
                            label: 'Valider',
                            icon: Icons.check,
                            variant: AjraButtonVariant.secondary,
                            isLoading: _isProcessing,
                            onPressed: () => _handleReview(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Admin Danger Zone
            if (currentUser.isAdmin &&
                _member.userId != currentUser.uid &&
                _member.email.toLowerCase().trim() != 'heriniaina.luk@gmail.com') ...[
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
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Zone de danger (Administration)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La suppression de ce compte effacera de manière irrévocable le compte utilisateur, son dossier d\'adhésion, ses cotisations, ses documents d\'identité et ses inscriptions.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 14),
                    AjraButton(
                      label: 'Supprimer définitivement ce compte et ses données',
                      icon: Icons.delete_forever,
                      variant: AjraButtonVariant.danger,
                      isLoading: _isProcessing,
                      onPressed: _handleDeleteMemberAccount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
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
    );
  }
}
