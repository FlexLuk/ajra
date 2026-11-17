import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_payment_method_selector.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/monthly_due.dart';
import '../repositories/dues_repository.dart';
import '../widgets/dues_summary_share_dialog.dart';
import '../../notifications/services/notification_service.dart';

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
                      initialValue: selectedMonth,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Mois'),
                      items: List.generate(12, (i) => i + 1).map((m) {
                        final label = DateFormat('MMMM', 'fr_FR').format(DateTime(2026, m));
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            label[0].toUpperCase() + label.substring(1),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      initialValue: selectedYear,
                      isExpanded: true,
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
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final isPrivileged = currentUser.isAdmin || currentUser.canVerifyPayments || currentUser.canRecordDues;
    final isAlreadyDeclared = due.status == DueStatus.declared;

    final refController = TextEditingController(text: due.transactionReference ?? '');
    final amountController = TextEditingController(
      text: (due.remainingAmount.cents > 0 ? due.remainingAmount : due.amount).inRupees.toStringAsFixed(0),
    );
    final notesController = TextEditingController(text: due.notes ?? '');
    String paymentMode = due.declaredPaymentMode ?? 'Virement Juice (MCB)';
    String selectedAccountId = AppConstants.accountJuice;
    bool directValidateAndDisburse = isPrivileged && due.userId != currentUser.uid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAlreadyDeclared
                      ? 'Modifier ma déclaration : ${due.periodLabel}'
                      : 'Déclarer un paiement : ${due.periodLabel}',
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membre : ${due.memberName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Montant restant dû : ${due.remainingAmount.toFormattedString()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                ),
                const SizedBox(height: 14),
                AjraPaymentMethodSelector(
                  initialMethod: paymentMode,
                  onChanged: (result) {
                    paymentMode = result.fullLabel;
                    setModalState(() {
                      final lower = paymentMode.toLowerCase();
                      if (lower.contains('juice')) {
                        selectedAccountId = AppConstants.accountJuice;
                      } else if (lower.contains('espèces') || lower.contains('especes') || lower.contains('cash')) {
                        selectedAccountId = AppConstants.accountCash;
                      } else {
                        selectedAccountId = AppConstants.accountBank;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant versé (MUR) *',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: refController,
                  label: 'Référence du versement (MCB Juice, Reçu...) *',
                  hint: 'ex: MCB-JUICE-884920 ou Reçu #12',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: notesController,
                  label: 'Commentaire facultatif',
                  hint: 'Précisions pour le bureau AJRA...',
                  maxLines: 2,
                ),
                if (isPrivileged) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Valider et encaisser immédiatement',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Crédite directement la trésorerie AJRA sans attendre',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                    value: directValidateAndDisburse,
                    onChanged: (val) {
                      setModalState(() => directValidateAndDisburse = val ?? false);
                    },
                  ),
                  if (directValidateAndDisburse) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Compte AJRA crédité *',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: AppConstants.accountBank,
                          child: Text('Compte Bancaire Principal AJRA', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.accountJuice,
                          child: Text('Compte Juice AJRA (MCB)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.accountCash,
                          child: Text('Caisse Espèces AJRA (Cash)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedAccountId = val);
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim()) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez renseigner un montant valide.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(
                directValidateAndDisburse ? 'Encaisser & Valider' : (isAlreadyDeclared ? 'Mettre à jour' : 'Déclarer le paiement'),
              ),
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

        if (isPrivileged && directValidateAndDisburse) {
          // Validation et encaissement direct par un gestionnaire
          await repo.verifyDuePayment(
            dueId: due.id,
            verifierUserId: currentUser.uid,
            verifierName: currentUser.displayName,
            verifierRole: currentUser.role.code,
            approve: true,
            verifiedAmount: parsedAmount,
            accountId: selectedAccountId,
            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          );

          if (due.userId != currentUser.uid) {
            await NotificationService.createUserNotification(
              recipientUserId: due.userId,
              title: 'Cotisation encaissée : ${due.periodLabel}',
              body: 'Votre versement de ${parsedAmount.toFormattedString()} pour ${due.periodLabel} a été encaissé.',
              type: 'due',
              targetRoute: '/dues',
              entityType: 'due',
              entityId: due.id,
              senderUserId: currentUser.uid,
              senderName: currentUser.displayName,
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.success,
                content: Text('Cotisation validée et trésorerie AJRA créditée avec succès !'),
              ),
            );
          }
        } else {
          // Déclaration ou modification de déclaration par le membre
          await repo.declareDuePayment(
            dueId: due.id,
            paymentMode: paymentMode,
            transactionReference: refController.text.trim().isNotEmpty
                ? refController.text.trim()
                : 'DEC-${DateTime.now().millisecondsSinceEpoch}',
            declaredAmount: parsedAmount,
            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          );

          // Notifier les administrateurs
          await NotificationService.notifyIfBureauAction(
            actorUserId: currentUser.uid,
            actorName: currentUser.displayName,
            actorRole: currentUser.role.code,
            title: isAlreadyDeclared ? 'Déclaration de cotisation modifiée' : 'Nouvelle déclaration de cotisation',
            body: '${due.memberName} a ${isAlreadyDeclared ? "modifié sa déclaration de" : "déclaré un"} paiement de ${parsedAmount.toFormattedString()} pour ${due.periodLabel}.',
            entityType: 'due',
            entityId: due.id,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text(
                  isAlreadyDeclared
                      ? 'Votre déclaration de cotisation a été mise à jour avec succès.'
                      : 'Votre paiement a été déclaré. Il sera validé par le bureau.',
                ),
              ),
            );
          }
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

  Future<void> _verifyDuePayment(MonthlyDue due, bool approve) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (approve) {
      String selectedAccountId = AppConstants.accountJuice;
      final amountController = TextEditingController(
        text: (due.remainingAmount.cents > 0 ? due.remainingAmount : due.amount).inRupees.toStringAsFixed(0),
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text('Valider l\'encaissement : ${due.memberName}')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cotisation : ${due.periodLabel}'),
                if (due.transactionReference != null && due.transactionReference!.isNotEmpty)
                  Text('Réf membre : ${due.transactionReference} (${due.declaredPaymentMode ?? ""})',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant encaissé (MUR) *',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Compte de trésorerie AJRA crédité *',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AppConstants.accountJuice,
                      child: Text('Compte Juice AJRA (MCB)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.accountBank,
                      child: Text('Compte Bancaire Principal AJRA', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.accountCash,
                      child: Text('Caisse Espèces AJRA (Cash)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedAccountId = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer l\'encaissement'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        final verifiedAmount = Money.fromRupees(double.tryParse(amountController.text.trim()) ?? due.amount.inRupees);
        try {
          final repo = ref.read(duesRepositoryProvider);
          await repo.verifyDuePayment(
            dueId: due.id,
            verifierUserId: currentUser.uid,
            verifierName: currentUser.displayName,
            verifierRole: currentUser.role.code,
            approve: true,
            verifiedAmount: verifiedAmount,
            accountId: selectedAccountId,
          );

          await NotificationService.createUserNotification(
            recipientUserId: due.userId,
            title: 'Cotisation validée : ${due.periodLabel}',
            body: 'Votre cotisation de ${verifiedAmount.toFormattedString()} pour ${due.periodLabel} a été vérifiée et validée par le bureau.',
            type: 'due',
            targetRoute: '/dues',
            entityType: 'due',
            entityId: due.id,
            senderUserId: currentUser.uid,
            senderName: currentUser.displayName,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.success,
                content: Text('Paiement validé avec succès. Trésorerie AJRA mise à jour.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.danger, content: Text('Erreur : ${e.toString()}')),
            );
          }
        }
      }
    } else {
      // Rejeter la déclaration
      final reasonController = TextEditingController(text: 'Paiement non constaté sur les comptes de l\'association.');

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.danger),
              SizedBox(width: 8),
              Expanded(child: Text('Rejeter la déclaration')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Membre : ${due.memberName} (${due.periodLabel})'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motif du rejet (visible par le membre) *',
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer le rejet'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          final repo = ref.read(duesRepositoryProvider);
          await repo.verifyDuePayment(
            dueId: due.id,
            verifierUserId: currentUser.uid,
            verifierName: currentUser.displayName,
            verifierRole: currentUser.role.code,
            approve: false,
            verifiedAmount: const Money.zero(),
            notes: reasonController.text.trim(),
          );

          await NotificationService.createUserNotification(
            recipientUserId: due.userId,
            title: 'Déclaration de cotisation refusée : ${due.periodLabel}',
            body: 'Votre déclaration pour ${due.periodLabel} a été refusée : ${reasonController.text.trim()}',
            type: 'due',
            targetRoute: '/dues',
            entityType: 'due',
            entityId: due.id,
            senderUserId: currentUser.uid,
            senderName: currentUser.displayName,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.warning,
                content: Text('Déclaration rejetée. Le membre a été notifié.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.danger, content: Text('Erreur : ${e.toString()}')),
            );
          }
        }
      }
    }
  }

  Future<void> _requestAmountChange(MonthlyDue due) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final amountController = TextEditingController(text: due.amountPaid.inRupees.toStringAsFixed(0));
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Demande de changement de montant')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cotisation : ${due.periodLabel} • Membre : ${due.memberName}'),
            const SizedBox(height: 6),
            Text('Montant actuel enregistré : ${due.amountPaid.toFormattedString()}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
            const SizedBox(height: 14),
            AjraCurrencyField(
              controller: amountController,
              label: 'Nouveau montant souhaité (MUR) *',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motif ou justification de la demande *',
                hintText: 'ex: J\'ai versé 500 MUR au lieu de 200 MUR, veuillez ajuster...',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (amountController.text.trim().isEmpty || reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez préciser le montant et le motif.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final requestedAmount = Money.fromRupees(double.tryParse(amountController.text.trim()) ?? due.amountPaid.inRupees);
      final reason = reasonController.text.trim();

      try {
        await FirebaseFirestore.instance.collection('dueChangeRequests').add({
          'dueId': due.id,
          'userId': currentUser.uid,
          'memberName': currentUser.displayName,
          'periodLabel': due.periodLabel,
          'currentAmountPaidCents': due.amountPaid.cents,
          'requestedAmountCents': requestedAmount.cents,
          'reason': reason,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        });

        await NotificationService.notifyIfBureauAction(
          actorUserId: currentUser.uid,
          actorName: currentUser.displayName,
          actorRole: currentUser.role.code,
          title: 'Demande de modification de cotisation',
          body: '${currentUser.displayName} demande de modifier sa cotisation de ${due.periodLabel} à ${requestedAmount.toFormattedString()} (Motif : $reason).',
          entityType: 'due',
          entityId: due.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Votre demande de modification a été transmise aux administrateurs.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Erreur : ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _notifyUserDue(MonthlyDue due) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final titleController = TextEditingController(
      text: 'Rappel de cotisation : ${due.periodLabel}',
    );
    final bodyController = TextEditingController(
      text: 'Bonjour ${due.memberName}, nous vous rappelons votre cotisation AJRA de ${due.remainingAmount.toFormattedString()} pour le mois de ${due.periodLabel}. Merci de bien vouloir procéder au règlement.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Notifier l\'utilisateur')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Envoyer un rappel directement sur le téléphone de ${due.memberName} :',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Titre de la notification',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message de rappel',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Envoyer la notification'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await NotificationService.createUserNotification(
          recipientUserId: due.userId,
          title: titleController.text.trim(),
          body: bodyController.text.trim(),
          type: 'due',
          targetRoute: '/dues',
          entityType: 'due',
          entityId: due.id,
          senderUserId: currentUser.uid,
          senderName: currentUser.displayName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Rappel envoyé avec succès sur le téléphone de ${due.memberName}.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('Erreur d\'envoi : ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteDue(MonthlyDue due) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette cotisation'),
        content: Text(
          'Voulez-vous supprimer l\'échéance ${due.periodLabel} de ${due.memberName} ? Si un paiement avait été encaissé, la trésorerie sera automatiquement rééquilibrée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(duesRepositoryProvider);
        await repo.deleteDue(
          dueId: due.id,
          adminUserId: currentUser.uid,
          adminName: currentUser.displayName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Cotisation supprimée avec succès.'),
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
          leading: const AjraBackButton(fallbackRoute: '/dashboard'),
          title: const Text('Cotisations Mensuelles'),
          actions: [
            if (isPrivileged) ...[
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Partager le récapitulatif (PNG / WhatsApp)',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const DuesSummaryShareDialog(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Générer échéances du mois',
                onPressed: _openGenerateDuesDialog,
              ),
            ],
          ],
          bottom: isPrivileged
              ? TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Mes cotisations'),
                    Tab(text: 'Toutes les cotisations'),
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

  Widget _buildShareBanner(List<MonthlyDue> dues) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partage WhatsApp du Mois',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Infographie PNG officielle & texte récapitulatif pour le groupe AJRA.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF065F46),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Exporter PNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => DuesSummaryShareDialog(dues: dues),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyDuesList([dynamic currentUser]) {
    final duesAsync = ref.watch(userDuesProvider);
    final user = currentUser ?? ref.watch(currentUserProvider);

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
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final due = dues[index];
            return _buildDueCard(due, isForVerification: false, currentUser: user);
          },
        );
      },
      loading: () => const LoadingStateView(message: 'Chargement des cotisations...'),
      error: (e, _) => ErrorStateView(
        message: e.toString(),
        onRetry: () => ref.refresh(userDuesProvider),
      ),
    );
  }

  Widget _buildAllDuesVerificationList(dynamic currentUser) {
    final allAsync = ref.watch(allDuesProvider);

    return allAsync.when(
      data: (dues) {
        if (dues.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildShareBanner(dues),
                const SizedBox(height: 20),
                const Expanded(
                  child: EmptyStateView(
                    icon: Icons.checklist_rtl_outlined,
                    title: 'Aucune cotisation en cours',
                    message: 'Toutes les cotisations sont à jour.',
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: dues.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildShareBanner(dues);
            }
            final due = dues[index - 1];
            return _buildDueCard(due, isForVerification: true, currentUser: currentUser);
          },
        );
      },
      loading: () => const LoadingStateView(message: 'Chargement des cotisations globales...'),
      error: (e, _) => ErrorStateView(
        message: e.toString(),
        onRetry: () => ref.refresh(allDuesProvider),
      ),
    );
  }

  Widget _buildDueCard(MonthlyDue due, {required bool isForVerification, dynamic currentUser}) {
    final isPrivileged = currentUser != null &&
        (currentUser.isAdmin || currentUser.canVerifyPayments || currentUser.canRecordDues);

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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Montant : ${due.amount.toFormattedString()}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              if (due.amountPaid.isPositive)
                Text(
                  '(Réglé : ${due.amountPaid.toFormattedString()})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (due.transactionReference != null && due.transactionReference!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Réf : ${due.transactionReference} (${due.declaredPaymentMode ?? "Hors-app"})',
              style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Bouton Déclarer ou Modifier la déclaration (si non validé)
              if (due.status != DueStatus.paid)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(
                    due.status == DueStatus.declared ? 'Modifier ma déclaration' : 'Déclarer un paiement',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _openDeclarePaymentModal(due),
                ),

              // 2. Boutons de validation et rejet pour le bureau / admin
              if (isForVerification && isPrivileged && due.status == DueStatus.declared) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Valider l\'encaissement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _verifyDuePayment(due, true),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Rejeter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _verifyDuePayment(due, false),
                ),
              ],

              // 3. Bouton Notifier l'utilisateur (rappel téléphonique)
              if (isPrivileged && due.status != DueStatus.paid)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF047857)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Notifier l\'utilisateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _notifyUserDue(due),
                ),

              // 4. Si validé : bouton demande de changement de montant
              if (due.status == DueStatus.paid)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: const Text('Demande de changement de montant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _requestAmountChange(due),
                ),

              // 5. Bouton Supprimer pour l'admin
              if (isPrivileged)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _deleteDue(due),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
