import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_payment_method_selector.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membership/providers/membership_provider.dart';
import '../models/membership_fee_config.dart';
import '../models/membership_payment.dart';
import '../repositories/membership_payment_repository.dart';

final membershipPaymentRepoProvider = Provider<BaseMembershipPaymentRepository>((ref) {
  return FirestoreMembershipPaymentRepository();
});

final feeConfigProvider = StreamProvider<MembershipFeeConfig>((ref) {
  return ref.watch(membershipPaymentRepoProvider).watchFeeConfig();
});

final userMembershipPaymentProvider = StreamProvider<MembershipPayment?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(membershipPaymentRepoProvider).watchPayment(user.uid);
});

class MembershipFeeScreen extends ConsumerStatefulWidget {
  const MembershipFeeScreen({super.key});

  @override
  ConsumerState<MembershipFeeScreen> createState() => _MembershipFeeScreenState();
}

class _MembershipFeeScreenState extends ConsumerState<MembershipFeeScreen> {
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMode = 'Virement bancaire MCB';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDeclaration(Money amount) async {
    final user = ref.read(currentUserProvider);
    final member = ref.read(currentMemberProfileProvider).value;
    if (user == null || member == null) return;

    if (_refController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner la référence de transaction du paiement.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(membershipPaymentRepoProvider);
      await repo.declarePayment(
        userId: user.uid,
        memberNumber: member.memberNumber,
        memberName: member.fullName,
        amount: amount,
        paymentMode: _paymentMode,
        transactionReference: _refController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Déclaration enregistrée ! Le trésorier effectuera la vérification sous peu.'),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(feeConfigProvider);
    final paymentAsync = ref.watch(userMembershipPaymentProvider);

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
        title: const Text('Droit d\'adhésion AJRA'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: configAsync.when(
            data: (config) {
              return paymentAsync.when(
                data: (payment) {
                  final isPaid = payment != null && payment.isVerified;
                  final isDeclared = payment != null && payment.isDeclared && !payment.isVerified;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Fee Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPaid
                                    ? [const Color(0xFF065F46), const Color(0xFF047857)]
                                    : [AppColors.primaryDark, AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (isPaid ? AppColors.success : AppColors.primary)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'DROIT D\'ADHÉSION UNIQUE',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    StatusBadge.paymentStatus(
                                      isVerified: isPaid,
                                      isDeclared: isDeclared,
                                      isRejected: payment?.isRejected ?? false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    config.amount.toFormattedString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isPaid
                                      ? 'Paiement confirmé le ${DateFormat("dd/MM/yyyy").format(payment.verifiedAt ?? DateTime.now())}'
                                      : 'Exigible à la validation de l\'adhésion pour devenir membre effectif.',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (!isPaid) ...[
                            // Payment Instructions Card
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
                                    'Modalités de règlement hors-application',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    config.bankInstructions,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryLight,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '1. Effectuez le virement bancaire ou remettez les espèces au trésorier.\n2. Renseignez ci-dessous la référence de la transaction.\n3. Le trésorier contrôlera la réception effective sur le compte de l\'AJRA.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondaryLight,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Declaration Form
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    isDeclared
                                        ? 'Mettre à jour la déclaration de paiement'
                                        : 'Déclarer mon paiement effectué',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AjraPaymentMethodSelector(
                                    onChanged: (res) {
                                      setState(() => _paymentMode = res.fullLabel);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  AjraTextField(
                                    controller: _refController,
                                    label: 'Référence de transaction / reçu bancaire *',
                                    hint: 'ex: FT26019XXXXX',
                                  ),
                                  const SizedBox(height: 14),
                                  AjraTextField(
                                    controller: _notesController,
                                    label: 'Commentaire facultatif',
                                    hint: 'ex: Virement effectué depuis mon compte personnel',
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 20),
                                  AjraButton(
                                    label: 'Transmettre la déclaration',
                                    icon: Icons.send_rounded,
                                    isLoading: _isSubmitting,
                                    onPressed: () => _submitDeclaration(config.amount),
                                    variant: AjraButtonVariant.primary,
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Validated Receipt Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.successLight),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 56, color: AppColors.success),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Droit d\'adhésion acquitté',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Votre règlement de ${payment.amount.toFormattedString()} a été validé par ${payment.verifiedByName ?? "le trésorier"}.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, height: 1.4),
                                  ),
                                  const Divider(height: 28),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Flexible(
                                        flex: 2,
                                        child: Text('Référence comptable :',
                                            style: TextStyle(
                                                fontSize: 12, color: AppColors.textSecondaryLight)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          payment.transactionReference ?? 'N/A',
                                          textAlign: TextAlign.right,
                                          softWrap: true,
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LoadingStateView(message: 'Vérification du dossier...'),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.refresh(userMembershipPaymentProvider),
                ),
              );
            },
            loading: () => const LoadingStateView(message: 'Chargement des paramètres...'),
            error: (e, _) => ErrorStateView(
              message: e.toString(),
              onRetry: () => ref.refresh(feeConfigProvider),
            ),
          ),
        ),
      ),
    );
  }
}
