import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_payment_method_selector.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membership_fees/models/membership_fee_config.dart';
import '../../membership_fees/models/membership_payment.dart';
import '../../membership_fees/screens/membership_fee_screen.dart';
import '../models/member_profile.dart';
import '../providers/membership_provider.dart';

class MembershipStatusScreen extends ConsumerStatefulWidget {
  const MembershipStatusScreen({super.key});

  @override
  ConsumerState<MembershipStatusScreen> createState() => _MembershipStatusScreenState();
}

class _MembershipStatusScreenState extends ConsumerState<MembershipStatusScreen> {
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMode = 'Juice MCB';
  bool _isSubmittingPayment = false;

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPaymentDeclaration(Money amount, MemberProfile? member) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (_refController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Veuillez saisir le numéro de transaction ou de référence de votre virement.'),
        ),
      );
      return;
    }

    setState(() => _isSubmittingPayment = true);
    try {
      final repo = ref.read(membershipPaymentRepoProvider);
      await repo.declarePayment(
        userId: user.uid,
        memberNumber: member?.memberNumber ?? 'AJRA-ATTENTE',
        memberName: member?.fullName ?? user.displayName,
        amount: amount,
        paymentMode: _paymentMode,
        transactionReference: _refController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Paiement déclaré avec succès ! Le trésorier effectuera la vérification sous peu.'),
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
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final memberAsync = ref.watch(currentMemberProfileProvider);
    final paymentAsync = ref.watch(userMembershipPaymentProvider);
    final feeConfigAsync = ref.watch(feeConfigProvider);

    final member = memberAsync.value;
    final payment = paymentAsync.value;
    final feeConfig = feeConfigAsync.value ?? MembershipFeeConfig.defaultConfig();

    final dateFormat = DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR');
    final expectedFee = member?.permitType == PermitType.student
        ? Money.fromRupees(1000)
        : feeConfig.amount;

    final isFullyActive = member != null && member.status == MembershipStatus.active;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Suivi de mon Adhésion & Cotisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gavel_rounded),
            tooltip: 'Statuts & RPD',
            onPressed: () => context.go('/about'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mon Profil',
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(currentMemberProfileProvider);
              ref.invalidate(userMembershipPaymentProvider);
              ref.invalidate(feeConfigProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Confidentiality Notice Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 20, color: Color(0xFF475569)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Espace de suivi confidentiel AJRA • ${user?.displayName ?? "Candidat"}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Celebration banner if validated
                  if (isFullyActive) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withValues(alpha: 0.15),
                            AppColors.success.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
                          const SizedBox(height: 10),
                          const Text(
                            'Félicitations ! Votre adhésion est validée.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Vous faites officiellement partie des membres actifs de l\'AJRA.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF047857)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          AjraButton(
                            label: 'Entrer dans l\'application AJRA',
                            icon: Icons.dashboard_rounded,
                            variant: AjraButtonVariant.primary,
                            onPressed: () => context.go('/dashboard'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // CARD 1 : État de la Demande d'Adhésion
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.assignment_ind_outlined, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '1. Dossier d\'Adhésion',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (member != null)
                                StatusBadge.fromMembershipStatus(member.status)
                              else
                                const StatusBadge(
                                  label: 'Non soumis',
                                  backgroundColor: Color(0xFFF3F4F6),
                                  textColor: Color(0xFF6B7280),
                                ),
                            ],
                          ),
                          const Divider(height: 24),

                          if (member == null) ...[
                            const Text(
                              'Vous n\'avez pas encore soumis votre demande d\'adhésion à l\'AJRA.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                            ),
                            const SizedBox(height: 16),
                            AjraButton(
                              label: 'Remplir ma demande d\'adhésion',
                              icon: Icons.edit_document,
                              variant: AjraButtonVariant.primary,
                              onPressed: () => context.go('/membership-apply'),
                            ),
                          ] else if (member.status == MembershipStatus.pending) ...[
                            Row(
                              children: [
                                const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Dossier en attente d\'examen par le bureau AJRA.',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoLine('Matricule provisoire', member.memberNumber),
                            _buildInfoLine('Nom et Prénom', member.fullName),
                            _buildInfoLine('Permis / Statut', member.permitType.label),
                            _buildInfoLine('Date de dépôt', dateFormat.format(member.appliedAt)),
                            const SizedBox(height: 10),
                            const Text(
                              'Le bureau AJRA examine votre dossier. Vous recevrez une notification dès que la décision sera enregistrée.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
                            ),
                          ] else if (member.status == MembershipStatus.rejected) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel, color: AppColors.danger, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Demande rejetée : ${member.reviewNotes ?? "Dossier incomplet."}',
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            AjraButton(
                              label: 'Corriger et soumettre à nouveau',
                              icon: Icons.refresh,
                              variant: AjraButtonVariant.primary,
                              onPressed: () => context.go('/membership-apply'),
                            ),
                          ] else if (member.status == MembershipStatus.active) ...[
                            _buildInfoLine('Matricule officiel', member.memberNumber),
                            _buildInfoLine('Nom du membre', member.fullName),
                            _buildInfoLine('Type de membre', member.permitType.label),
                            if (member.approvedAt != null)
                              _buildInfoLine('Validé le', dateFormat.format(member.approvedAt!)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // CARD 2 : État de la Cotisation (Droit d'Adhésion)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.receipt_long_outlined, color: AppColors.secondaryDark, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '2. Cotisation (Droit d\'Adhésion)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (payment != null && payment.isVerified)
                                const StatusBadge(
                                  label: 'Vérifié & Réglé',
                                  backgroundColor: AppColors.successLight,
                                  textColor: AppColors.success,
                                )
                              else if (payment != null && payment.isPendingVerification)
                                const StatusBadge(
                                  label: 'Vérification en cours',
                                  backgroundColor: AppColors.warningLight,
                                  textColor: AppColors.warning,
                                )
                              else
                                const StatusBadge(
                                  label: 'À régler',
                                  backgroundColor: Color(0xFFFEF3C7),
                                  textColor: Color(0xFFD97706),
                                ),
                            ],
                          ),
                          const Divider(height: 24),

                          _buildInfoLine('Montant applicable', expectedFee.formatted),

                          if (payment != null && payment.isVerified) ...[
                            const SizedBox(height: 8),
                            _buildInfoLine('Mode de paiement', payment.paymentMode ?? 'Virement'),
                            _buildInfoLine('Référence transaction', payment.transactionReference ?? 'N/A'),
                            if (payment.verifiedAt != null)
                              _buildInfoLine('Vérifié le', dateFormat.format(payment.verifiedAt!)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified, color: AppColors.success, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Votre droit d\'adhésion est en règle. Merci pour votre engagement solidaire !',
                                      style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (payment != null && payment.isPendingVerification) ...[
                            const SizedBox(height: 8),
                            _buildInfoLine('Mode déclaré', payment.paymentMode ?? 'Virement'),
                            _buildInfoLine('Référence transmise', payment.transactionReference ?? 'N/A'),
                            if (payment.declaredAt != null)
                              _buildInfoLine('Déclaré le', dateFormat.format(payment.declaredAt!)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.pending_actions, color: AppColors.warning, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Paiement transmis au trésorier. La vérification bancaire est en cours.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            // Bank Details Box
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Coordonnées bancaires pour le virement :',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildBankInfoRow('Banque', 'Mauritius Commercial Bank (MCB)'),
                                  _buildBankInfoRow('Compte MCB', '000445678910 - AJRA Maurice'),
                                  _buildBankInfoRow('Juice MCB', '+230 5845 1234'),
                                  _buildBankInfoRow('Référence', member?.memberNumber ?? user?.displayName ?? 'Adhésion'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Text(
                              'Déclarer votre paiement une fois le virement effectué :',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 10),

                            AjraPaymentMethodSelector(
                              onChanged: (res) {
                                setState(() => _paymentMode = res.fullLabel);
                              },
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: _refController,
                              decoration: const InputDecoration(
                                labelText: 'Numéro de transaction / Référence reçu',
                                hintText: 'ex: MCB-TX-987654 ou N° reçu',
                              ),
                            ),

                            const SizedBox(height: 16),

                            AjraButton(
                              label: 'Déclarer mon paiement',
                              icon: Icons.check_circle_outline,
                              variant: AjraButtonVariant.primary,
                              isLoading: _isSubmittingPayment,
                              onPressed: () => _submitPaymentDeclaration(expectedFee, member),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Statuts de l'AJRA & RPD Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
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
                          'Prenez connaissance des 15 statuts officiels fondateurs régissant l\'association AJRA ainsi que la politique de protection des données (RPD).',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
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
                            if (kIsWeb) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('APK Android', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => context.go('/about'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Confidentiality Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: AppColors.textSecondaryLight),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Politique de Confidentialité AJRA :\nL\'annuaire complet des membres, les relevés de trésorerie et les assemblées sont strictement réservés aux membres validés et enregistrés de l\'association.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryLight,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBankInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
