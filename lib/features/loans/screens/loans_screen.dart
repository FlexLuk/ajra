import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/cards/metric_card.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_payment_method_selector.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/member_loan.dart';
import '../providers/loan_provider.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  String _selectedFilter = 'all'; // 'all', 'approved', 'pending', 'repaid', 'overdue'

  Future<void> _openNewLoanDialog() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final nameController = TextEditingController(text: user.displayName);
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final purposeController = TextEditingController();
    final notesController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    bool disburseImmediately = false;
    String selectedDisbursementAccount = AppConstants.accountCash;
    final canDirectDisburse = user.role.isAdmin || user.role.isBureau;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.handshake_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Demande d\'emprunt solidaire')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transparence : Cette demande sera visible par l\'ensemble des membres de l\'association.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AjraTextField(
                  controller: nameController,
                  label: 'Nom de l\'emprunteur *',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: phoneController,
                  label: 'Numéro de contact (Maurice)',
                  hint: '+230 5...',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant souhaité (${AppConstants.currencySymbol}) *',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: purposeController,
                  label: 'Motif de l\'emprunt *',
                  hint: 'ex: Avance loyer, soins médicaux, billets...',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                AjraDateField(
                  label: 'Date d\'échéance du remboursement *',
                  initialDate: dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateSelected: (date) {
                    setModalState(() => dueDate = date);
                  },
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: notesController,
                  label: 'Remarques ou modalités prévues',
                  hint: 'ex: Remboursement en 2 tranches par Juice MCB...',
                  maxLines: 2,
                ),
                if (canDirectDisburse) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Valider et décaisser immédiatement',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Déduit immédiatement le montant du compte AJRA sélectionné',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                    value: disburseImmediately,
                    onChanged: (val) {
                      setModalState(() => disburseImmediately = val ?? false);
                    },
                  ),
                  if (disburseImmediately) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedDisbursementAccount,
                      decoration: const InputDecoration(
                        labelText: 'Compte AJRA à débiter *',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: AppConstants.accountCash, child: Text('Caisse Espèces AJRA')),
                        DropdownMenuItem(value: AppConstants.accountBank, child: Text('Compte Bancaire Principal AJRA')),
                        DropdownMenuItem(value: AppConstants.accountJuice, child: Text('Compte Juice AJRA (MCB)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedDisbursementAccount = v);
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                if (nameController.text.trim().isEmpty || amt <= 0 || purposeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez renseigner le nom, le montant et le motif.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Soumettre la demande', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final amount = Money.fromRupees(double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0);
      final loanId = const Uuid().v4();

      final newLoan = MemberLoan(
        id: loanId,
        borrowerUserId: user.uid,
        borrowerName: nameController.text.trim(),
        borrowerPhone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
        amount: amount,
        purpose: purposeController.text.trim(),
        requestedAt: DateTime.now(),
        dueDate: dueDate,
        status: LoanStatus.pending,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(loanRepoProvider);
      await repo.requestLoan(newLoan);

      if (disburseImmediately) {
        await repo.approveLoan(
          loanId: loanId,
          approverUserId: user.uid,
          approverName: user.displayName,
          approverRole: user.role.code,
          accountId: selectedDisbursementAccount,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              disburseImmediately
                  ? 'Emprunt créé, validé et montant déduit de la trésorerie AJRA avec succès.'
                  : 'Demande d\'emprunt enregistrée avec succès (en attente de validation).',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteLoan(MemberLoan loan) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'emprunt'),
        content: Text(
          'Voulez-vous supprimer l\'emprunt de ${loan.borrowerName} (${loan.amount.toFormattedString()}) ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(loanRepoProvider).deleteLoan(
        loanId: loan.id,
        adminUserId: user.uid,
        adminName: user.displayName,
        adminRole: user.role.code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Emprunt supprimé avec succès.'),
          ),
        );
      }
    }
  }

  Future<void> _openRepaymentDialog(MemberLoan loan) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final canRecord = user.role.isAdmin || (user.role.isBureau && user.uid != loan.borrowerUserId);
    if (!canRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Seul un administrateur ou un membre du bureau non emprunteur peut enregistrer un remboursement.'),
        ),
      );
      return;
    }

    final amountController = TextEditingController(text: loan.remainingAmount.inRupees.toStringAsFixed(0));
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMode = 'Virement par Juice (MCB)';
    String selectedAccountId = AppConstants.accountJuice;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Rembourser : ${loan.borrowerName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solde restant dû : ${loan.remainingAmount.toFormattedString()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant versé (${AppConstants.currencySymbol}) *',
                ),
                const SizedBox(height: 12),
                AjraPaymentMethodSelector(
                  onChanged: (res) {
                    selectedMode = res.fullLabel;
                    selectedAccountId = res.targetAccountId;
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Compte AJRA crédité *'),
                  items: const [
                    DropdownMenuItem(value: AppConstants.accountCash, child: Text('Caisse Espèces')),
                    DropdownMenuItem(value: AppConstants.accountBank, child: Text('Compte Bancaire Principal')),
                    DropdownMenuItem(value: AppConstants.accountJuice, child: Text('Juice (MCB)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedAccountId = v);
                  },
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: refController,
                  label: 'Référence / Reçu',
                  hint: 'ex: ID transaction Juice ou n° reçu',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: notesController,
                  label: 'Remarques',
                  hint: 'ex: Remboursement partiel...',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez saisir un montant valide.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Confirmer le remboursement', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final amount = Money.fromRupees(double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0);
      final repayment = LoanRepayment(
        id: const Uuid().v4(),
        loanId: loan.id,
        amount: amount,
        repaymentDate: DateTime.now(),
        paymentMode: selectedMode,
        reference: refController.text.trim().isNotEmpty ? refController.text.trim() : 'REM-${DateTime.now().millisecondsSinceEpoch}',
        recordedByUserId: user.uid,
        recordedByName: user.displayName,
        accountId: selectedAccountId,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await ref.read(loanRepoProvider).recordRepayment(
        loanId: loan.id,
        repayment: repayment,
        targetAccountId: selectedAccountId,
        recorderRole: user.role.code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Remboursement enregistré et crédité sur le compte de l\'association.'),
          ),
        );
      }
    }
  }

  Future<void> _approveLoan(MemberLoan loan) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    String selectedDisbursementAccount = AppConstants.accountCash;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Approuver et décaisser l\'emprunt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirmez-vous l\'accord et le versement de ${loan.amount.toFormattedString()} à ${loan.borrowerName} ?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedDisbursementAccount,
                decoration: const InputDecoration(labelText: 'Compte de l\'association à débiter *'),
                items: const [
                  DropdownMenuItem(value: AppConstants.accountCash, child: Text('Caisse Espèces')),
                  DropdownMenuItem(value: AppConstants.accountBank, child: Text('Compte Bancaire Principal')),
                  DropdownMenuItem(value: AppConstants.accountJuice, child: Text('Juice (MCB)')),
                ],
                onChanged: (v) {
                  if (v != null) setModalState(() => selectedDisbursementAccount = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Valider et Décaisser', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(loanRepoProvider).approveLoan(
        loanId: loan.id,
        approverUserId: user.uid,
        approverName: user.displayName,
        approverRole: user.role.code,
        accountId: selectedDisbursementAccount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Emprunt validé et fonds décaissés de la trésorerie.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final loansAsync = ref.watch(loansStreamProvider);
    final stats = ref.watch(loanStatsProvider);
    final canManage = user?.role.isAdmin == true || user?.role.isBureau == true;

    return AppScaffold(
      selectedIndex: 3, // Section Trésorerie & Finances
      child: Scaffold(
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
          title: const Text('Emprunts des Membres'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: () => ref.refresh(loansStreamProvider),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière de Transparence Publique Associative
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.handshake_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transparence Totale sur les Emprunts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tous les membres ont accès aux montants empruntés, aux motifs et aux remboursements en cours pour garantir l\'intégrité des fonds associatifs.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cartes de statistiques
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Total Emprunté',
                      value: stats.totalLoaned.toFormattedString(),
                      icon: Icons.account_balance_outlined,
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'Total Remboursé',
                      value: stats.totalRepaid.toFormattedString(),
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Solde Restant Dû',
                      value: stats.totalOutstanding.toFormattedString(),
                      icon: Icons.pending_actions_outlined,
                      iconColor: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'Emprunts Actifs',
                      value: '${stats.activeLoansCount}',
                      subtitle: stats.overdueLoansCount > 0 ? '${stats.overdueLoansCount} en retard' : 'Tous à jour',
                      icon: Icons.people_outline,
                      iconColor: stats.overdueLoansCount > 0 ? AppColors.danger : AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bouton pour faire une nouvelle demande
              AjraButton(
                label: 'Demander un nouvel emprunt',
                icon: Icons.add_circle_outline,
                onPressed: _openNewLoanDialog,
                variant: AjraButtonVariant.primary,
              ),
              const SizedBox(height: 20),

              // Filtres
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tous', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En cours', 'approved'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En attente', 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Remboursés', 'repaid'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En retard', 'overdue'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Liste des emprunts
              loansAsync.when(
                data: (allLoans) {
                  final filtered = allLoans.where((l) {
                    if (_selectedFilter == 'approved') return l.status == LoanStatus.approved && !l.isOverdueCalculated;
                    if (_selectedFilter == 'pending') return l.status == LoanStatus.pending;
                    if (_selectedFilter == 'repaid') return l.status == LoanStatus.repaid;
                    if (_selectedFilter == 'overdue') return l.isOverdueCalculated;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.handshake_outlined,
                      title: 'Aucun emprunt trouvé',
                      message: 'Aucun enregistrement ne correspond aux filtres sélectionnés.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final loan = filtered[index];
                      return _buildLoanCard(context, loan, canManage);
                    },
                  );
                },
                loading: () => const LoadingStateView(message: 'Chargement des emprunts...'),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.refresh(loansStreamProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildLoanCard(BuildContext context, MemberLoan loan, bool canManage) {
    final currentUser = ref.watch(currentUserProvider);
    final bool canRecordRepayment = currentUser != null && (
      currentUser.role.isAdmin ||
      (currentUser.role.isBureau && currentUser.uid != loan.borrowerUserId)
    );

    Color statusBg;
    Color statusFg;
    String statusLabel = loan.status.label;

    if (loan.isOverdueCalculated) {
      statusBg = AppColors.dangerLight;
      statusFg = AppColors.danger;
      statusLabel = 'En retard';
    } else {
      switch (loan.status) {
        case LoanStatus.approved:
          statusBg = AppColors.primaryLight.withValues(alpha: 0.15);
          statusFg = AppColors.primary;
          break;
        case LoanStatus.repaid:
          statusBg = AppColors.successLight;
          statusFg = AppColors.success;
          break;
        case LoanStatus.rejected:
          statusBg = AppColors.dangerLight;
          statusFg = AppColors.danger;
          break;
        case LoanStatus.overdue:
          statusBg = AppColors.dangerLight;
          statusFg = AppColors.danger;
          break;
        case LoanStatus.pending:
        default:
          statusBg = AppColors.warningLight;
          statusFg = AppColors.warning;
          break;
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: loan.isOverdueCalculated ? AppColors.danger.withValues(alpha: 0.4) : AppColors.borderLight,
          width: loan.isOverdueCalculated ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Nom + Statut
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                child: Text(
                  loan.borrowerName.isNotEmpty ? loan.borrowerName[0].toUpperCase() : 'M',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.borrowerName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    if (loan.borrowerPhone != null)
                      Text(
                        loan.borrowerPhone!,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMutedLight),
                  tooltip: 'Supprimer cet emprunt',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteLoan(loan),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Motif
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondaryLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Motif : ${loan.purpose}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Montants & Progression
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emprunté', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  Text(
                    loan.amount.toFormattedString(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Remboursé', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  Text(
                    loan.amountRepaid.toFormattedString(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Reste dû', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  Text(
                    loan.remainingAmount.toFormattedString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: loan.remainingAmount.cents > 0 ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: loan.repaymentProgress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                loan.status == LoanStatus.repaid ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dates d'échéance et de demande
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Text(
                'Échéance : ${dateFormat.format(loan.dueDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: loan.isOverdueCalculated ? FontWeight.bold : FontWeight.normal,
                  color: loan.isOverdueCalculated ? AppColors.danger : null,
                ),
              ),
              const Spacer(),
              Text(
                'Demandé le ${dateFormat.format(loan.requestedAt)}',
                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ],
          ),

          // Actions
          if (loan.status == LoanStatus.pending && canManage) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref.read(loanRepoProvider).rejectLoan(loan.id, 'Refusé par le bureau'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Rejeter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveLoan(loan),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: const Text('Valider & Décaisser', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ] else if ((loan.status == LoanStatus.approved || loan.isOverdueCalculated) && canRecordRepayment) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: AjraButton(
                    label: 'Enregistrer un remboursement',
                    icon: Icons.payments_outlined,
                    onPressed: () => _openRepaymentDialog(loan),
                    variant: AjraButtonVariant.secondary,
                    height: 40,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
