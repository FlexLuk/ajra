import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/cards/metric_card.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../accounting/models/financial_account.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../accounting/providers/accounting_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dues/widgets/dues_summary_share_dialog.dart';

export '../../accounting/providers/accounting_provider.dart';

class TreasuryDashboardScreen extends ConsumerStatefulWidget {
  const TreasuryDashboardScreen({super.key});

  @override
  ConsumerState<TreasuryDashboardScreen> createState() => _TreasuryDashboardScreenState();
}

class _TreasuryDashboardScreenState extends ConsumerState<TreasuryDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionStatus? _filterStatus;
  TransactionType? _filterType;
  String? _filterAccountId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filterStatus = null;
      _filterType = null;
      _filterAccountId = null;
    });
  }

  List<FinancialTransaction> _getFilteredTransactions(List<FinancialTransaction> transactions) {
    return transactions.where((tx) {
      if (_filterStatus != null && tx.status != _filterStatus) {
        return false;
      }
      if (_filterType != null && tx.type != _filterType) {
        return false;
      }
      if (_filterAccountId != null) {
        final matchesSource = tx.accountId == _filterAccountId;
        final matchesDest = tx.targetAccountId == _filterAccountId;
        if (!matchesSource && !matchesDest) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesDesc = tx.description.toLowerCase().contains(q);
        final matchesCat = tx.category.toLowerCase().contains(q);
        final matchesMode = tx.paymentMode.toLowerCase().contains(q);
        final matchesRef = tx.reference.toLowerCase().contains(q);
        final matchesCreator = tx.createdByName.toLowerCase().contains(q);
        final matchesValidator = tx.validatedByName?.toLowerCase().contains(q) ?? false;
        final matchesAmount = tx.amount.inRupees.toString().contains(q) ||
            tx.amount.toFormattedString().toLowerCase().contains(q);

        if (!matchesDesc &&
            !matchesCat &&
            !matchesMode &&
            !matchesRef &&
            !matchesCreator &&
            !matchesValidator &&
            !matchesAmount) {
          return false;
        }
      }
      return true;
    }).toList();
  }

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
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCategory = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccount,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Compte concerné'),
                  items: const [
                    DropdownMenuItem(
                      value: AppConstants.accountCash,
                      child: Text('Caisse Espèces', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.accountBank,
                      child: Text('Compte Bancaire Principal', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.accountJuice,
                      child: Text('Juice (MCB)', overflow: TextOverflow.ellipsis),
                    ),
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
        paymentMode: selectedAccount == AppConstants.accountCash
            ? 'Espèces'
            : (selectedAccount == AppConstants.accountJuice ? 'Virement Juice' : 'Transfert bancaire'),
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
          title: const Text('Portefeuille & Trésorerie AJRA'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Partager le bilan des cotisations (PNG / WhatsApp)',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const DuesSummaryShareDialog(),
                );
              },
            ),
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
            final filteredTxs = _getFilteredTransactions(allTxs);

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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            netBalance.toFormattedString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Recettes validées',
                                          style: TextStyle(color: Colors.white60, fontSize: 11),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            totalIncome.toFormattedString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Dépenses validées',
                                          style: TextStyle(color: Colors.white60, fontSize: 11),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            totalExpense.toFormattedString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Builder(
                          builder: (context) {
                            final totalVolume = totalIncomeCents + totalExpenseCents;
                            final incomeRatio =
                                totalVolume > 0 ? (totalIncomeCents / totalVolume) : 1.0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: incomeRatio.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: AppColors.danger.withValues(alpha: 0.45),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF34D399),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${validatedTxs.length} écriture(s) validée(s)',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () async {
                                        final dateStr =
                                            DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
                                        final summary =
                                            '📊 *BILAN TRÉSORERIE AJRA* ($dateStr)\n'
                                            '━━━━━━━━━━━━━━━━━━\n'
                                            '💰 *Solde Global Net* : ${netBalance.toFormattedString()}\n'
                                            '📈 *Recettes validées* : ${totalIncome.toFormattedString()}\n'
                                            '📉 *Dépenses validées* : ${totalExpense.toFormattedString()}\n'
                                            '⏳ *Opérations en attente* : ${pendingTxs.length} (${pendingTotal.toFormattedString()})\n'
                                            '━━━━━━━━━━━━━━━━━━\n'
                                            '🇲🇬 🇲🇺 _Association des Jeunes de la Région Anosy_';
                                        await Clipboard.setData(ClipboardData(text: summary));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              backgroundColor: AppColors.success,
                                              content: Text(
                                                'Résumé de trésorerie copié ! Vous pouvez le coller sur WhatsApp.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.copy_all_rounded, size: 14, color: Colors.white),
                                            SizedBox(width: 5),
                                            Text(
                                              'Copier résumé WhatsApp',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
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

                  // Accounts Grid (Responsive so 3 accounts never crowd mobile width)
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            Widget buildAccCard(FinancialAccount acc) {
                              final isCash = acc.id == AppConstants.accountCash;
                              final isJuice = acc.id == AppConstants.accountJuice;
                              return MetricCard(
                                title: acc.name,
                                value: acc.currentBalance.toFormattedString(),
                                icon: isCash
                                    ? Icons.payments_outlined
                                    : (isJuice
                                        ? Icons.phone_android_rounded
                                        : Icons.account_balance_outlined),
                                iconColor: isCash
                                    ? AppColors.secondary
                                    : (isJuice ? const Color(0xFFF97316) : AppColors.primary),
                              );
                            }

                            if (constraints.maxWidth >= 680) {
                              return Row(
                                children: [
                                  for (int i = 0; i < accounts.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 12),
                                    Expanded(child: buildAccCard(accounts[i])),
                                  ],
                                ],
                              );
                            }

                            if (accounts.length == 3 && constraints.maxWidth >= 340) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: buildAccCard(accounts[0])),
                                      const SizedBox(width: 10),
                                      Expanded(child: buildAccCard(accounts[1])),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  buildAccCard(accounts[2]),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int i = 0; i < accounts.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  buildAccCard(accounts[i]),
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  // Raccourci vers Emprunts des Membres
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emprunts des Membres',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Registre transparent des aides remboursables',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/loans'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Consulter', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Operations List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Écritures comptables',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${allTxs.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: canCreate ? _openNewTransactionModal : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nouvelle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher (libellé, réf, membre, montant...)',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMutedLight),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips Scrollable Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Status Filters
                        ChoiceChip(
                          label: Text('Toutes (${allTxs.length})'),
                          selected: _filterStatus == null && _filterType == null && _filterAccountId == null,
                          onSelected: (_) => _resetFilters(),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: pendingTxs.isNotEmpty
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.warning,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          label: Text('En attente (${pendingTxs.length})'),
                          selected: _filterStatus == TransactionStatus.pending,
                          selectedColor: AppColors.warningLight,
                          onSelected: (_) => setState(() {
                            _filterStatus = _filterStatus == TransactionStatus.pending ? null : TransactionStatus.pending;
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Validées (${validatedTxs.length})'),
                          selected: _filterStatus == TransactionStatus.validated,
                          selectedColor: AppColors.successLight,
                          onSelected: (_) => setState(() {
                            _filterStatus = _filterStatus == TransactionStatus.validated ? null : TransactionStatus.validated;
                          }),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 22, color: AppColors.borderLight),
                        const SizedBox(width: 12),
                        // Type Filters
                        FilterChip(
                          label: const Text('Recettes'),
                          selected: _filterType == TransactionType.income,
                          selectedColor: AppColors.successLight,
                          onSelected: (_) => setState(() {
                            _filterType = _filterType == TransactionType.income ? null : TransactionType.income;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Dépenses'),
                          selected: _filterType == TransactionType.expense,
                          selectedColor: AppColors.dangerLight,
                          onSelected: (_) => setState(() {
                            _filterType = _filterType == TransactionType.expense ? null : TransactionType.expense;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Virements'),
                          selected: _filterType == TransactionType.transfer,
                          onSelected: (_) => setState(() {
                            _filterType = _filterType == TransactionType.transfer ? null : TransactionType.transfer;
                          }),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 22, color: AppColors.borderLight),
                        const SizedBox(width: 12),
                        // Account Filters
                        FilterChip(
                          label: const Text('Caisse Espèces'),
                          selected: _filterAccountId == AppConstants.accountCash,
                          onSelected: (_) => setState(() {
                            _filterAccountId = _filterAccountId == AppConstants.accountCash ? null : AppConstants.accountCash;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Banque'),
                          selected: _filterAccountId == AppConstants.accountBank,
                          onSelected: (_) => setState(() {
                            _filterAccountId = _filterAccountId == AppConstants.accountBank ? null : AppConstants.accountBank;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Juice'),
                          selected: _filterAccountId == AppConstants.accountJuice,
                          onSelected: (_) => setState(() {
                            _filterAccountId = _filterAccountId == AppConstants.accountJuice ? null : AppConstants.accountJuice;
                          }),
                        ),
                      ],
                    ),
                  ),

                  // Results Counter and Reset when filtered
                  if (_searchQuery.isNotEmpty || _filterStatus != null || _filterType != null || _filterAccountId != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${filteredTxs.length} écriture(s) trouvée(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _resetFilters,
                            child: const Text(
                              'Réinitialiser',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  if (allTxs.isEmpty)
                    const EmptyStateView(
                      icon: Icons.receipt_outlined,
                      title: 'Aucune écriture comptable',
                      message: 'Les opérations financières apparaîtront ici.',
                    )
                  else if (filteredTxs.isEmpty)
                    EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'Aucune écriture correspondante',
                      message: 'Aucune opération ne correspond à vos filtres ou termes de recherche.',
                      actionLabel: 'Effacer les filtres',
                      onAction: _resetFilters,
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTxs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = filteredTxs[index];
                        final isIncome = tx.type == TransactionType.income;
                        final isExpense = tx.type == TransactionType.expense;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tx.status == TransactionStatus.pending
                                  ? AppColors.warning.withValues(alpha: 0.5)
                                  : AppColors.borderLight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${DateFormat("dd/MM/yyyy").format(tx.date)} • ${tx.category} • ${tx.paymentMode}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                    if (tx.reference.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Réf : ${tx.reference}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    if (tx.createdByName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Saisie par : ${tx.createdByName}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textMutedLight,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                  const SizedBox(height: 6),
                                  if (tx.status == TransactionStatus.pending && canApprove)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check, size: 14),
                                      label: const Text('Valider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _validatePendingTx(tx),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tx.status == TransactionStatus.validated
                                            ? AppColors.successLight
                                            : AppColors.borderLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tx.status.label,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: tx.status == TransactionStatus.validated
                                              ? AppColors.success
                                              : AppColors.textSecondaryLight,
                                        ),
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
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.refresh(recentTransactionsProvider),
          ),
        ),
      ),
    );
  }
}
