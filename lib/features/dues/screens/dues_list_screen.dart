import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/monthly_due.dart';
import '../repositories/dues_repository.dart';

final duesRepositoryProvider = Provider<BaseDuesRepository>((ref) {
  return FirestoreDuesRepository();
});

final userDuesProvider = StreamProvider<List<MonthlyDue>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(duesRepositoryProvider).watchUserDues(user.uid);
});

final allDuesProvider = StreamProvider<List<MonthlyDue>>((ref) {
  return ref.watch(duesRepositoryProvider).watchAllDues();
});

class DuesListScreen extends ConsumerStatefulWidget {
  const DuesListScreen({super.key});

  @override
  ConsumerState<DuesListScreen> createState() => _DuesListScreenState();
}

class _DuesListScreenState extends ConsumerState<DuesListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openGenerateDuesDialog() async {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    final amountController = TextEditingController(text: '150');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Générer les cotisations'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette opération génère l\'échéance mensuelle pour tous les membres actifs de l\'AJRA (sans doublon).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedMonth,
                      decoration: const InputDecoration(labelText: 'Mois'),
                      items: List.generate(12, (i) => i + 1).map((m) {
                        final label = DateFormat('MMMM', 'fr_FR').format(DateTime(2026, m));
                        return DropdownMenuItem(
                          value: m,
                          child: Text(label[0].toUpperCase() + label.substring(1)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedMonth = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: const InputDecoration(labelText: 'Année'),
                      items: [2025, 2026, 2027].map((y) {
                        return DropdownMenuItem(value: y, child: Text(y.toString()));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedYear = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AjraCurrencyField(
                controller: amountController,
                label: 'Montant de la cotisation (MUR)',
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
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final amount = Money.fromRupees(double.tryParse(amountController.text.trim()) ?? 150);

      try {
        final repo = ref.read(duesRepositoryProvider);
        await repo.generateDuesForMonth(
          year: selectedYear,
          month: selectedMonth,
          amountPerMember: amount,
          generatedByUserId: user.uid,
          generatedByName: user.displayName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Cotisations générées avec succès pour les membres actifs.'),
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
      }
    }
  }

  Future<void> _openDeclarePaymentModal(MonthlyDue due) async {
    final refController = TextEditingController();
    final amountController = TextEditingController(text: due.remainingAmount.inRupees.toString());
    final notesController = TextEditingController();
    String paymentMode = 'Remise espèces';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Déclarer la cotisation : ${due.periodLabel}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Montant restant dû : ${due.remainingAmount.toFormattedString()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Mode de paiement effectué'),
                  items: const [
                    DropdownMenuItem(value: 'Remise espèces', child: Text('Remise en espèces')),
                    DropdownMenuItem(value: 'Virement MCB', child: Text('Virement bancaire MCB')),
                    DropdownMenuItem(value: 'Virement SBM', child: Text('Virement bancaire SBM')),
                    DropdownMenuItem(value: 'Autre banque', child: Text('Autre virement bancaire')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => paymentMode = v);
                  },
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant versé (MUR)',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: refController,
                  label: 'Référence du virement ou du reçu',
                  hint: 'ex: MCB-TRX-998811',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: notesController,
                  label: 'Commentaire facultatif',
                  maxLines: 2,
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
              child: const Text('Soumettre la déclaration'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final parsedAmount =
          Money.fromRupees(double.tryParse(amountController.text.trim()) ?? due.remainingAmount.inRupees);
      try {
        final repo = ref.read(duesRepositoryProvider);
        await repo.declareDuePayment(
          dueId: due.id,
          paymentMode: paymentMode,
          transactionReference: refController.text.trim().isEmpty
              ? 'MANUEL-${DateTime.now().millisecondsSinceEpoch}'
              : refController.text.trim(),
          declaredAmount: parsedAmount,
          notes: notesController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Déclaration de paiement enregistrée en attente de vérification.'),
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
      }
    }
  }

  Future<void> _verifyDue(MonthlyDue due, bool approve) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (due.userId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Séparation des fonctions : Vous ne pouvez pas valider votre propre cotisation.'),
        ),
      );
      return;
    }

    final notesController = TextEditingController();
    final amountController = TextEditingController(text: due.remainingAmount.inRupees.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Confirmer le règlement' : 'Rejeter la déclaration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Confirmez la bonne réception effective des fonds pour ${due.memberName} (${due.periodLabel}) :'
                  : 'Indiquez le motif du rejet (fonds non reçus, référence introuvable...) :',
            ),
            const SizedBox(height: 12),
            if (approve)
              AjraCurrencyField(
                controller: amountController,
                label: 'Montant réel encaissé (MUR)',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(hintText: 'Remarques...'),
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
            child: Text(approve ? 'Valider et encaisser' : 'Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final verifiedAmount =
          Money.fromRupees(double.tryParse(amountController.text.trim()) ?? due.remainingAmount.inRupees);
      try {
        final repo = ref.read(duesRepositoryProvider);
        await repo.verifyDuePayment(
          dueId: due.id,
          verifierUserId: currentUser.uid,
          verifierName: currentUser.displayName,
          verifierRole: currentUser.role.code,
          approve: approve,
          verifiedAmount: verifiedAmount,
          notes: notesController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: approve ? AppColors.success : AppColors.danger,
              content: Text(
                approve
                    ? 'Cotisation validée et enregistrée en trésorerie.'
                    : 'Déclaration rejetée.',
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isPrivileged = currentUser != null &&
        (currentUser.isAdmin || currentUser.canVerifyPayments || currentUser.canRecordDues);

    return AppScaffold(
      selectedIndex: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cotisations Mensuelles'),
          actions: [
            if (isPrivileged)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Générer échéances du mois',
                onPressed: _openGenerateDuesDialog,
              ),
          ],
          bottom: isPrivileged
              ? TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Mes cotisations'),
                    Tab(text: 'Vérification / Bureau'),
                  ],
                )
              : null,
        ),
        body: isPrivileged
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildMyDuesList(),
                  _buildAllDuesVerificationList(currentUser),
                ],
              )
            : _buildMyDuesList(),
      ),
    );
  }

  Widget _buildMyDuesList() {
    final duesAsync = ref.watch(userDuesProvider);

    return duesAsync.when(
      data: (dues) {
        if (dues.isEmpty) {
          return const EmptyStateView(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune cotisation enregistrée',
            message: 'Vos échéances mensuelles apparaîtront ici dès leur génération par le bureau.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: dues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final due = dues[index];
            return _buildDueCard(due, isForVerification: false);
          },
        );
      },
      loading: () => const LoadingStateView(message: 'Chargement des cotisations...'),
      error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
    );
  }

  Widget _buildAllDuesVerificationList(dynamic currentUser) {
    final allAsync = ref.watch(allDuesProvider);

    return allAsync.when(
      data: (dues) {
        if (dues.isEmpty) {
          return const EmptyStateView(
            icon: Icons.checklist_rtl_outlined,
            title: 'Aucune cotisation en cours',
            message: 'Toutes les cotisations sont à jour.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: dues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final due = dues[index];
            return _buildDueCard(due, isForVerification: true, currentUser: currentUser);
          },
        );
      },
      loading: () => const LoadingStateView(message: 'Chargement des cotisations globales...'),
      error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
    );
  }

  Widget _buildDueCard(MonthlyDue due, {required bool isForVerification, dynamic currentUser}) {
    final canVerifyThis = isForVerification &&
        currentUser != null &&
        currentUser.uid != due.userId &&
        (due.status == DueStatus.declared || due.status == DueStatus.pending);

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isForVerification ? '${due.memberName} • ${due.periodLabel}' : due.periodLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              StatusBadge.paymentStatus(
                isVerified: due.status == DueStatus.paid,
                isDeclared: due.status == DueStatus.declared,
                isRejected: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Montant : ${due.amount.toFormattedString()}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              if (due.amountPaid.isPositive) ...[
                const SizedBox(width: 8),
                Text(
                  '(Réglé : ${due.amountPaid.toFormattedString()})',
                  style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          if (due.transactionReference != null && due.transactionReference!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Réf : ${due.transactionReference} (${due.declaredPaymentMode ?? "Hors-app"})',
              style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
            ),
          ],
          const SizedBox(height: 12),
          if (!isForVerification && due.status != DueStatus.paid) ...[
            AjraButton(
              label: due.status == DueStatus.declared ? 'Modifier ma déclaration' : 'Déclarer un paiement',
              icon: Icons.payments_outlined,
              variant: AjraButtonVariant.primary,
              height: 40,
              onPressed: () => _openDeclarePaymentModal(due),
            ),
          ],
          if (canVerifyThis) ...[
            Row(
              children: [
                Expanded(
                  child: AjraButton(
                    label: 'Rejeter',
                    variant: AjraButtonVariant.danger,
                    height: 38,
                    onPressed: () => _verifyDue(due, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AjraButton(
                    label: 'Valider l\'encaissement',
                    variant: AjraButtonVariant.secondary,
                    height: 38,
                    onPressed: () => _verifyDue(due, true),
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
