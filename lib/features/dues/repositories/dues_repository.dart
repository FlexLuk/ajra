import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/utils/money.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../audit/models/audit_log_entry.dart';
import '../../membership/models/member_profile.dart';
import '../models/monthly_due.dart';

abstract class BaseDuesRepository {
  Stream<List<MonthlyDue>> watchUserDues(String userId);
  Stream<List<MonthlyDue>> watchAllDues({int? year, int? month, DueStatus? status});
  Future<void> generateDuesForMonth({
    required int year,
    required int month,
    required Money amountPerMember,
    required String generatedByUserId,
    required String generatedByName,
  });
  Future<void> declareDuePayment({
    required String dueId,
    required String paymentMode,
    required String transactionReference,
    required Money declaredAmount,
    String? proofUrl,
    String? notes,
  });
  Future<void> verifyDuePayment({
    required String dueId,
    required String verifierUserId,
    required String verifierName,
    required String verifierRole,
    required bool approve,
    required Money verifiedAmount,
    String accountId = AppConstants.accountCash,
    String? notes,
  });
  Future<void> deleteDue({
    required String dueId,
    required String adminUserId,
    required String adminName,
  });
}

class FirestoreDuesRepository implements BaseDuesRepository {
  final FirebaseFirestore _firestore;

  FirestoreDuesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _duesCol =>
      _firestore.collection(AppConstants.colDues);

  CollectionReference<Map<String, dynamic>> get _membersCol =>
      _firestore.collection(AppConstants.colMembers);

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _firestore.collection(AppConstants.colFinancialTransactions);

  CollectionReference<Map<String, dynamic>> get _accountsCol =>
      _firestore.collection(AppConstants.colFinancialAccounts);

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _firestore.collection(AppConstants.colAuditLogs);

  @override
  Stream<List<MonthlyDue>> watchUserDues(String userId) {
    return _duesCol
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MonthlyDue.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        final cmp = b.periodYear.compareTo(a.periodYear);
        if (cmp != 0) return cmp;
        return b.periodMonth.compareTo(a.periodMonth);
      });
      return list;
    });
  }

  @override
  Stream<List<MonthlyDue>> watchAllDues({int? year, int? month, DueStatus? status}) {
    return _duesCol.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => MonthlyDue.fromJson(doc.data(), doc.id))
          .toList();

      if (year != null) {
        list = list.where((d) => d.periodYear == year).toList();
      }
      if (month != null) {
        list = list.where((d) => d.periodMonth == month).toList();
      }
      if (status != null) {
        list = list.where((d) => d.status == status).toList();
      }

      list.sort((a, b) {
        final cmp = b.periodYear.compareTo(a.periodYear);
        if (cmp != 0) return cmp;
        return b.periodMonth.compareTo(a.periodMonth);
      });

      return list;
    });
  }

  @override
  Future<void> generateDuesForMonth({
    required int year,
    required int month,
    required Money amountPerMember,
    required String generatedByUserId,
    required String generatedByName,
  }) async {
    // 1. Obtenir tous les membres actifs
    final activeMembersSnapshot = await _membersCol
        .where('status', isEqualTo: MembershipStatus.active.name)
        .get();

    final rawMembers = activeMembersSnapshot.docs
        .map((d) => MemberProfile.fromJson(d.data(), d.id))
        .toList();

    // Déduplication stricte par userId et par email pour éviter de générer des cotisations en double
    final seenUserIds = <String>{};
    final seenEmails = <String>{};
    final activeMembers = <MemberProfile>[];

    for (final m in rawMembers) {
      if (seenUserIds.contains(m.userId)) continue;
      final normEmail = m.email.trim().toLowerCase();
      if (normEmail.isNotEmpty && seenEmails.contains(normEmail)) continue;

      seenUserIds.add(m.userId);
      if (normEmail.isNotEmpty) seenEmails.add(normEmail);
      activeMembers.add(m);
    }

    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime(year, month));
    final periodLabel = monthName[0].toUpperCase() + monthName.substring(1);

    final batch = _firestore.batch();
    final now = DateTime.now();

    int generatedCount = 0;
    for (final member in activeMembers) {
      // Idempotence: identifiant déterministe
      final dueId = '${member.userId}_${year}_${month.toString().padLeft(2, '0')}';
      final dueRef = _duesCol.doc(dueId);

      final existing = await dueRef.get();
      if (!existing.exists) {
        final due = MonthlyDue(
          id: dueId,
          userId: member.userId,
          memberNumber: member.memberNumber,
          memberName: member.fullName,
          periodYear: year,
          periodMonth: month,
          periodLabel: periodLabel,
          amount: amountPerMember,
          amountPaid: const Money.zero(),
          status: DueStatus.pending,
          createdAt: now,
          updatedAt: now,
        );
        batch.set(dueRef, due.toJson());
        generatedCount++;
      }
    }

    if (generatedCount > 0) {
      await batch.commit();

      // Audit Log
      final audit = AuditLogEntry(
        id: _auditCol.doc().id,
        userId: generatedByUserId,
        userName: generatedByName,
        userRole: 'BUREAU',
        action: 'dues.generated',
        entityType: 'dues',
        entityId: '${year}_${month.toString().padLeft(2, '0')}',
        details: {
          'periodLabel': periodLabel,
          'count': generatedCount,
          'amountCents': amountPerMember.cents,
        },
        timestamp: now,
      );
      await _auditCol.doc(audit.id).set(audit.toJson());
    }
  }

  @override
  Future<void> declareDuePayment({
    required String dueId,
    required String paymentMode,
    required String transactionReference,
    required Money declaredAmount,
    String? proofUrl,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _duesCol.doc(dueId).update({
      'status': DueStatus.declared.name,
      'declaredPaymentMode': paymentMode,
      'transactionReference': transactionReference,
      'proofUrl': proofUrl,
      'notes': notes,
      'declaredAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    final doc = await _duesCol.doc(dueId).get();
    final memberName = doc.data()?['memberName'] ?? 'Membre';
    final userId = doc.data()?['userId'] ?? '';

    // Audit Log
    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: userId,
      userName: memberName,
      userRole: 'MEMBRE',
      action: 'dues.payment.declared',
      entityType: 'due',
      entityId: dueId,
      details: {
        'declaredAmountCents': declaredAmount.cents,
        'reference': transactionReference,
        'mode': paymentMode,
      },
      timestamp: now,
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> verifyDuePayment({
    required String dueId,
    required String verifierUserId,
    required String verifierName,
    required String verifierRole,
    required bool approve,
    required Money verifiedAmount,
    String accountId = AppConstants.accountCash,
    String? notes,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final dueDocRef = _duesCol.doc(dueId);
      final dueSnapshot = await transaction.get(dueDocRef);

      if (!dueSnapshot.exists) throw Exception('Cotisation introuvable');
      final due = MonthlyDue.fromJson(dueSnapshot.data()!, dueId);

      // TOUTES LES LECTURES (READS) DOIVENT ÊTRE EXÉCUTÉES AVANT LE PREMIER WRITE
      final accountDocRef = _accountsCol.doc(accountId);
      DocumentSnapshot<Map<String, dynamic>>? accountSnapshot;
      if (approve) {
        accountSnapshot = await transaction.get(accountDocRef);
      }

      final now = DateTime.now();

      if (approve) {
        // Calcul du nouveau montant payé
        final newTotalPaid = due.amountPaid + verifiedAmount;
        final newStatus =
            newTotalPaid >= due.amount ? DueStatus.paid : DueStatus.partiallyPaid;

        // 1. Créer UNE SEULE écriture financière validée
        final txId = const Uuid().v4();
        final txDocRef = _txCol.doc(txId);

        final financialTx = FinancialTransaction(
          id: txId,
          type: TransactionType.income,
          category: 'Cotisations mensuelles',
          amount: verifiedAmount,
          date: now,
          description:
              'Cotisation ${due.periodLabel} - ${due.memberName} (${due.memberNumber})',
          paymentMode: due.declaredPaymentMode ?? 'Hors-application',
          reference: due.transactionReference ?? 'REF-COTIS-$dueId',
          receiptUrl: due.proofUrl,
          accountId: accountId,
          createdByUserId: verifierUserId,
          createdByName: verifierName,
          validatedByUserId: verifierUserId,
          validatedByName: verifierName,
          status: TransactionStatus.validated,
          linkedEntityType: 'dues',
          linkedEntityId: dueId,
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(txDocRef, financialTx.toJson());

        // 2. Mettre à jour le solde du compte financier
        final currentCents = (accountSnapshot?.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
        transaction.set(accountDocRef, {
          'currentBalanceCents': currentCents + verifiedAmount.cents,
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));

        // 3. Mettre à jour la cotisation
        transaction.update(dueDocRef, {
          'status': newStatus.name,
          'amountPaidCents': newTotalPaid.cents,
          'verifiedAt': now.toIso8601String(),
          'verifiedByUserId': verifierUserId,
          'verifiedByName': verifierName,
          'financialTransactionId': txId,
          'notes': notes ?? due.notes,
          'updatedAt': now.toIso8601String(),
        });
      } else {
        // Rejeter la déclaration
        transaction.update(dueDocRef, {
          'status': DueStatus.pending.name,
          'notes': notes ?? 'Paiement non constaté sur le compte.',
          'updatedAt': now.toIso8601String(),
        });
      }

      // 4. Audit Log
      final auditDocRef = _auditCol.doc();
      transaction.set(auditDocRef, {
        'userId': verifierUserId,
        'userName': verifierName,
        'userRole': verifierRole,
        'action': approve ? 'dues.payment.verified' : 'dues.payment.rejected',
        'entityType': 'due',
        'entityId': dueId,
        'details': {
          'approved': approve,
          'amountCents': verifiedAmount.cents,
        },
        'timestamp': now.toIso8601String(),
      });
    });
  }

  @override
  Future<void> deleteDue({
    required String dueId,
    required String adminUserId,
    required String adminName,
  }) async {
    final docRef = _duesCol.doc(dueId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final amountPaidCents = (data['amountPaidCents'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();

    // Si la cotisation supprimée comportait un montant encaissé, créer une écriture de dépense
    // de régularisation pour contrepasser l'encaissement et équilibrer le compte financier (caisse/banque/juice).
    if (amountPaidCents > 0) {
      String accountId = AppConstants.accountCash;
      final txId = data['financialTransactionId'] as String?;
      if (txId != null && txId.isNotEmpty) {
        try {
          final txDoc = await _txCol.doc(txId).get();
          if (txDoc.exists) {
            accountId = (txDoc.data()?['accountId'] as String?) ?? accountId;
          }
        } catch (_) {}
      }

      final expenseTxId = const Uuid().v4();
      final memberName = data['memberName'] ?? 'Membre';
      final periodYear = data['periodYear'] ?? '';
      final periodMonth = data['periodMonth'] ?? '';

      // 1. Créer la transaction de dépense d'équilibrage
      final balancingTx = FinancialTransaction(
        id: expenseTxId,
        type: TransactionType.expense,
        category: 'Régularisation doublon cotisation',
        amount: Money.fromCents(amountPaidCents),
        date: now,
        description:
            'Régularisation doublon / annulation cotisation : $memberName ($periodMonth/$periodYear)',
        paymentMode: data['declaredPaymentMode'] ?? 'Virement/Espèces',
        reference: 'REGUL-$dueId',
        receiptUrl: null,
        accountId: accountId,
        createdByUserId: adminUserId,
        createdByName: adminName,
        validatedByUserId: adminUserId,
        validatedByName: adminName,
        status: TransactionStatus.validated,
        linkedEntityType: 'dues_reversal',
        linkedEntityId: dueId,
        createdAt: now,
        updatedAt: now,
      );
      await _txCol.doc(expenseTxId).set(balancingTx.toJson());

      // 2. Déduire le montant du compte financier pour balancer la caisse
      final accDocRef = _accountsCol.doc(accountId);
      final accSnap = await accDocRef.get();
      if (accSnap.exists) {
        final currentCents = (accSnap.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
        await accDocRef.update({
          'currentBalanceCents': currentCents - amountPaidCents,
          'updatedAt': now.toIso8601String(),
        });
      }
    }

    await docRef.delete();

    // Audit Log
    await _auditCol.doc().set({
      'userId': adminUserId,
      'userName': adminName,
      'userRole': UserRole.admin.code,
      'action': 'dues.deleted',
      'entityType': 'due',
      'entityId': dueId,
      'details': {
        'dueId': dueId,
        'userId': data['userId'],
        'memberName': data['memberName'],
        'period': '${data['periodYear']}_${data['periodMonth']}',
        'amountPaidCentsReversed': amountPaidCents,
      },
      'timestamp': now.toIso8601String(),
    });
  }
}
