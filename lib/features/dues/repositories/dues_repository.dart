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
        .orderBy('periodYear', descending: true)
        .orderBy('periodMonth', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MonthlyDue.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<List<MonthlyDue>> watchAllDues({int? year, int? month, DueStatus? status}) {
    Query<Map<String, dynamic>> query = _duesCol
        .orderBy('periodYear', descending: true)
        .orderBy('periodMonth', descending: true);

    if (year != null) {
      query = query.where('periodYear', isEqualTo: year);
    }
    if (month != null) {
      query = query.where('periodMonth', isEqualTo: month);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MonthlyDue.fromJson(doc.data(), doc.id))
          .toList();
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

    final activeMembers = activeMembersSnapshot.docs
        .map((d) => MemberProfile.fromJson(d.data(), d.id))
        .toList();

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

      // Règle de séparation des fonctions: ne peut s'auto-valider
      if (due.userId == verifierUserId) {
        throw Exception('Règle de sécurité : Vous ne pouvez pas confirmer votre propre cotisation.');
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
        final accountDocRef = _accountsCol.doc(accountId);
        final accountSnapshot = await transaction.get(accountDocRef);
        final currentCents = (accountSnapshot.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
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
}
