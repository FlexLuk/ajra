import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/cards/metric_card.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../accounting/models/financial_account.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../accounting/repositories/accounting_repository.dart';
import '../../auth/providers/auth_provider.dart';

final accountingRepoProvider = Provider<BaseAccountingRepository>((ref) {
  return FirestoreAccountingRepository();
});

final accountsStreamProvider = StreamProvider<List<FinancialAccount>>((ref) {
  return ref.watch(accountingRepoProvider).watchAccounts();
});

final recentTransactionsProvider = StreamProvider<List<FinancialTransaction>>((ref) {
  return ref.watch(accountingRepoProvider).watchTransactions();
});

class TreasuryDashboardScreen extends ConsumerStatefulWidget {
  const TreasuryDashboardScreen({super.key});

  @override
  ConsumerState<TreasuryDashboardScreen> createState() => _TreasuryDashboardScreenState();
}

class _TreasuryDashboardScreenState extends ConsumerState<TreasuryDashboardScreen> {
  Future<void> _openNewTransactionModal() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final descController = TextEditingController();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    TransactionType selectedType = TransactionType.expense;
    String selectedCategory = 'Fournitures';
    String selectedAccount = AppConstants.accountCash;
    DateTime selectedDate = DateTime.now();

    final categories = [
      'Droits d\'adhésion',
      'Cotisations mensuelles',
      'Dons & Collectes',
      'Location salle',
      'Transport',
      'Restauration & Événements',
      'Fournitures & Impressions',
      'Frais bancaires & Administratif',
      'Autre',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Nouvelle opération financière'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Dépense')),
                        selected: selectedType == TransactionType.expense,
                        selectedColor: AppColors.dangerLight,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedType = TransactionType.expense);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Recette')),
                        selected: selectedType == TransactionType.income,
                        selectedColor: AppColors.successLight,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedType = TransactionType.income);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant (MUR)',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCategory = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedAccount,
                  decoration: const InputDecoration(labelText: 'Compte concerné'),
                  items: const [
                    DropdownMenuItem(value: AppConstants.accountCash, child: Text('Caisse Espèces')),
                    DropdownMenuItem(value: AppConstants.accountBank, child: Text('Compte Bancaire Principal')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedAccount = v);
                  },
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: descController,
                  label: 'Description / Libellé de l\'opération',
                  hint: 'ex: Achat de fournitures pour l\'assemblée générale',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: refController,
                  label: 'Référence du reçu ou de la facture',
                  hint: 'ex: FACT-2026-004',
                ),
                const SizedBox(height: 12),
                AjraDateField(
                  label: 'Date de l\'opération',
                  initialDate: selectedDate,
                  firstDate: DateTime(2025),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  onDateSelected: (d) => selectedDate = d,
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer l\'opération'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final amount = Money.fromRupees(double.tryParse(amountController.text.trim()) ?? 0);
      if (amount.isZero) return;

      final now = DateTime.now();
      final txId = const Uuid().v4();

      final tx = FinancialTransaction(
        id: txId,
        type: selectedType,
        category: selectedCategory,
        amount: amount,
        date: selectedDate,
        description: descController.text.trim().isEmpty ? 'Opération diverse' : descController.text.trim(),
        paymentMode: selectedAccount == AppConstants.accountCash ? 'Espèces' : 'Virement bancaire',
        reference: refController.text.trim().isEmpty ? 'REF-$txId' : refController.text.trim(),
        accountId: selectedAccount,
        createdByUserId: user.uid,
        createdByName: user.displayName,
        status: user.isAdmin || user.canApproveTransaction
            ? TransactionStatus.validated
            : TransactionStatus.pending,
        validatedByUserId: user.isAdmin || user.canApproveTransaction ? user.uid : null,
        validatedByName: user.isAdmin || user.canApproveTransaction ? user.displayName : null,
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(accountingRepoProvider);
      await repo.createTransaction(tx);

      // Si l'utilisateur est admin ou valideur, on valide directement l'impact sur le solde
      if (tx.status == TransactionStatus.validated) {
        await repo.validateTransaction(
          transactionId: tx.id,
          validatorUserId: user.uid,
          validatorName: user.displayName,
          validatorRole: user.role.code,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              tx.status == TransactionStatus.validated
                  ? 'Opération validée et prise en compte dans le solde.'
                  : 'Opération créée en attente de validation par le trésorier.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _validatePendingTx(FinancialTransaction tx) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider l\'opération financière'),
        content: Text(
          'Voulez-vous valider ${tx.type.label.toLowerCase()} de ${tx.amount.toFormattedString()} (${tx.description}) ? Cette action mettra à jour le solde officiel.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider l\'écriture'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(accountingRepoProvider);
      await repo.validateTransaction(
        transactionId: tx.id,
        validatorUserId: user.uid,
        validatorName: user.displayName,
        validatorRole: user.role.code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Écriture validée avec succès.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);

    final canCreate = user != null && (user.isAdmin || user.canCreateTransaction);
    final canApprove = user != null && (user.isAdmin || user.canApproveTransaction);

    return AppScaffold(
      selectedIndex: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Portefeuille & Trésorerie AJRA'),
          actions: [
            if (canCreate)
              IconButton(
                icon: const Icon(Icons.add_card),
                tooltip: 'Saisir une opération',
                onPressed: _openNewTransactionModal,
              ),
          ],
        ),
        body: txsAsync.when(
          data: (allTxs) {
            final validatedTxs =
                allTxs.where((t) => t.status == TransactionStatus.validated).toList();
            final pendingTxs =
                allTxs.where((t) => t.status == TransactionStatus.pending).toList();

            int totalIncomeCents = 0;
            int totalExpenseCents = 0;

            for (final t in validatedTxs) {
              if (t.type == TransactionType.income) totalIncomeCents += t.amount.cents;
              if (t.type == TransactionType.expense) totalExpenseCents += t.amount.cents;
            }

            final netBalance = Money.fromCents(totalIncomeCents - totalExpenseCents);
            final totalIncome = Money.fromCents(totalIncomeCents);
            final totalExpense = Money.fromCents(totalExpenseCents);

            int pendingTotalCents = 0;
            for (final t in pendingTxs) {
              pendingTotalCents += t.amount.cents;
            }
            final pendingTotal = Money.fromCents(pendingTotalCents);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Balance Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SOLDE GLOBAL DE TRÉSORERIE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          netBalance.toFormattedString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_downward,
                                        size: 16, color: AppColors.successLight),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Recettes validées',
                                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                                      Text(
                                        totalIncome.toFormattedString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: Colors.white24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_upward,
                                        size: 16, color: AppColors.dangerLight),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Dépenses validées',
                                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                                      Text(
                                        totalExpense.toFormattedString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pending Transactions Alert (if any)
                  if (pendingTxs.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pendingTxs.length} opération(s) en attente (${pendingTotal.toFormattedString()})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const Text(
                                  'Ces montants n\'affectent pas le solde tant qu\'ils ne sont pas validés.',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Accounts Row
                  accountsAsync.when(
                    data: (accounts) {
                      return Row(
                        children: accounts.map((acc) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: MetricCard(
                                title: acc.name,
                                value: acc.currentBalance.toFormattedString(),
                                icon: acc.id == AppConstants.accountCash
                                    ? Icons.payments_outlined
                                    : Icons.account_balance_outlined,
                                iconColor: acc.id == AppConstants.accountCash
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // Operations List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historique des écritures comptables',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: canCreate ? _openNewTransactionModal : null,
                        child: const Text('Nouvelle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (allTxs.isEmpty)
                    const EmptyStateView(
                      icon: Icons.receipt_outlined,
                      title: 'Aucune écriture comptable',
                      message: 'Les opérations financières validées apparaîtront ici.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: allTxs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = allTxs[index];
                        final isIncome = tx.type == TransactionType.income;
                        final isExpense = tx.type == TransactionType.expense;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? AppColors.successLight
                                      : isExpense
                                          ? AppColors.dangerLight
                                          : AppColors.infoLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward
                                      : isExpense
                                          ? Icons.arrow_upward
                                          : Icons.swap_horiz,
                                  size: 18,
                                  color: isIncome
                                      ? AppColors.success
                                      : isExpense
                                          ? AppColors.danger
                                          : AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.description,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${DateFormat("dd/MM/yyyy").format(tx.date)} • ${tx.category} • ${tx.paymentMode}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIncome ? "+" : isExpense ? "-" : ""}${tx.amount.toFormattedString()}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isIncome
                                          ? AppColors.success
                                          : isExpense
                                              ? AppColors.danger
                                              : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (tx.status == TransactionStatus.pending && canApprove)
                                    InkWell(
                                      onTap: () => _validatePendingTx(tx),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.warningLight,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Valider',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      tx.status.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tx.status == TransactionStatus.validated
                                            ? AppColors.success
                                            : AppColors.textMutedLight,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
          loading: () => const LoadingStateView(message: 'Calcul de la trésorerie...'),
          error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
        ),
      ),
    );
  }
}
