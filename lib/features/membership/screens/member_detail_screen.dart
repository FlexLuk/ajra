import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isPrivileged = currentUser != null &&
        (currentUser.isAdmin || currentUser.canReviewMembership || currentUser.uid == _member.userId);
    final canReview = currentUser != null &&
        (currentUser.isAdmin || currentUser.canReviewMembership) &&
        currentUser.uid != _member.userId &&
        _member.isPending;

    final dateFormat = DateFormat('dd MMMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: Text(_member.fullName),
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
            const SizedBox(height: 24),

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
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
