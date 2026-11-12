import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../notifications/services/notification_service.dart';
import '../models/member_loan.dart';

abstract class BaseLoanRepository {
  Stream<List<MemberLoan>> watchLoans();
  Future<void> requestLoan(MemberLoan loan);
  Future<void> approveLoan({
    required String loanId,
    required String approverUserId,
    required String approverName,
    required String approverRole,
    required String accountId,
  });
  Future<void> rejectLoan(String loanId, String reason);
  Future<void> recordRepayment({
    required String loanId,
    required LoanRepayment repayment,
    required String targetAccountId,
    required String recorderRole,
  });
  Future<void> deleteLoan({
    required String loanId,
    required String adminUserId,
    required String adminName,
    required String adminRole,
  });
}

class FirestoreLoanRepository implements BaseLoanRepository {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  FirestoreLoanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<MemberLoan>> watchLoans() {
    return _firestore
        .collection(AppConstants.colLoans)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MemberLoan.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  @override
  Future<void> requestLoan(MemberLoan loan) async {
    final loanId = loan.id.isEmpty ? _uuid.v4() : loan.id;
    final finalLoan = loan.copyWith(updatedAt: DateTime.now());

    await _firestore
        .collection(AppConstants.colLoans)
        .doc(loanId)
        .set(finalLoan.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> approveLoan({
    required String loanId,
    required String approverUserId,
    required String approverName,
    required String approverRole,
    required String accountId,
  }) async {
    final loanDocRef = _firestore.collection(AppConstants.colLoans).doc(loanId);
    final loanSnap = await loanDocRef.get();
    final loanData = loanSnap.data() ?? {};
    final amountCents = (loanData['amountCents'] as num?)?.toInt() ?? 0;
    final borrowerName = (loanData['borrowerName'] as String?) ?? 'Membre';
    final purpose = (loanData['purpose'] as String?) ?? 'Aide solidaire';

    await loanDocRef.update({
      'status': LoanStatus.approved.name,
      'approvedAt': DateTime.now().toIso8601String(),
      'approvedByUserId': approverUserId,
      'approvedByName': approverName,
      'accountId': accountId,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 1. Débiter le compte financier de l'association sélectionné (Caisse, Banque ou Juice)
    final accountDocRef = _firestore.collection(AppConstants.colFinancialAccounts).doc(accountId);
    final accountSnap = await accountDocRef.get();
    final currentAccBalance = (accountSnap.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
    await accountDocRef.set({
      'currentBalanceCents': currentAccBalance - amountCents,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    // 2. Créer une écriture comptable de décaissement (Expense)
    final txId = const Uuid().v4();
    final paymentMode = accountId == AppConstants.accountCash
        ? 'Espèces'
        : (accountId == AppConstants.accountJuice ? 'Virement Juice' : 'Transfert bancaire');

    await _firestore.collection(AppConstants.colFinancialTransactions).doc(txId).set({
      'type': TransactionType.expense.name,
      'category': 'Emprunt membre',
      'amountCents': amountCents,
      'date': DateTime.now().toIso8601String(),
      'description': 'Décaissement emprunt solidaire accordé à $borrowerName ($purpose)',
      'paymentMode': paymentMode,
      'reference': 'EMP-${loanId.length > 8 ? loanId.substring(0, 8) : loanId}',
      'accountId': accountId,
      'createdByUserId': approverUserId,
      'createdByName': approverName,
      'validatedByUserId': approverUserId,
      'validatedByName': approverName,
      'status': TransactionStatus.validated.name,
      'linkedEntityType': 'loan',
      'linkedEntityId': loanId,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 3. Consigner dans le journal d'audit
    await _firestore.collection(AppConstants.colAuditLogs).doc().set({
      'userId': approverUserId,
      'userName': approverName,
      'userRole': approverRole,
      'action': 'loan.disbursed',
      'entityType': 'loan',
      'entityId': loanId,
      'details': {
        'loanId': loanId,
        'borrowerName': borrowerName,
        'amountCents': amountCents,
        'accountId': accountId,
        'transactionId': txId,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 4. Notification pour tous si action de membre du bureau
    await NotificationService.notifyIfBureauAction(
      actorUserId: approverUserId,
      actorName: approverName,
      actorRole: approverRole,
      title: 'Emprunt solidaire accordé',
      body: 'Un emprunt de ${Money.fromCents(amountCents).toFormattedString()} a été accordé et décaissé à $borrowerName.',
      entityType: 'loan',
      entityId: loanId,
    );
  }

  @override
  Future<void> rejectLoan(String loanId, String reason) async {
    await _firestore.collection(AppConstants.colLoans).doc(loanId).update({
      'status': LoanStatus.rejected.name,
      'notes': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> recordRepayment({
    required String loanId,
    required LoanRepayment repayment,
    required String targetAccountId,
    required String recorderRole,
  }) async {
    final docRef = _firestore.collection(AppConstants.colLoans).doc(loanId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final borrowerName = (doc.data()?['borrowerName'] as String?) ?? 'Membre';
    final currentAmountRepaid = (doc.data()?['amountRepaidCents'] as num?)?.toInt() ?? 0;
    final totalAmount = (doc.data()?['amountCents'] as num?)?.toInt() ?? 0;
    final newTotalRepaid = currentAmountRepaid + repayment.amount.cents;

    await docRef.update({
      'amountRepaidCents': newTotalRepaid,
      'status': newTotalRepaid >= totalAmount
          ? LoanStatus.repaid.name
          : LoanStatus.approved.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await docRef
        .collection(AppConstants.colLoanRepayments)
        .doc(repayment.id)
        .set(repayment.toJson());

    // 1. Créditer le compte de trésorerie de l'association (Caisse, Banque ou Juice)
    final accountDocRef = _firestore.collection(AppConstants.colFinancialAccounts).doc(targetAccountId);
    final accountSnap = await accountDocRef.get();
    final currentAccBalance = (accountSnap.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
    await accountDocRef.set({
      'currentBalanceCents': currentAccBalance + repayment.amount.cents,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    // 2. Enregistrer l'écriture financière d'encaissement (Income)
    final txId = const Uuid().v4();
    await _firestore.collection(AppConstants.colFinancialTransactions).doc(txId).set({
      'type': TransactionType.income.name,
      'category': 'Remboursement emprunt',
      'amountCents': repayment.amount.cents,
      'date': DateTime.now().toIso8601String(),
      'description': 'Remboursement d\'emprunt solidaire par $borrowerName (Réf: ${repayment.reference})',
      'paymentMode': repayment.paymentMode,
      'reference': repayment.reference,
      'accountId': targetAccountId,
      'createdByUserId': repayment.recordedByUserId,
      'createdByName': repayment.recordedByName,
      'validatedByUserId': repayment.recordedByUserId,
      'validatedByName': repayment.recordedByName,
      'status': TransactionStatus.validated.name,
      'linkedEntityType': 'loan',
      'linkedEntityId': loanId,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 3. Consigner dans le journal d'audit
    await _firestore.collection(AppConstants.colAuditLogs).doc().set({
      'userId': repayment.recordedByUserId,
      'userName': repayment.recordedByName,
      'userRole': recorderRole,
      'action': 'loan.repaid',
      'entityType': 'loan',
      'entityId': loanId,
      'details': {
        'loanId': loanId,
        'borrowerName': borrowerName,
        'amountCents': repayment.amount.cents,
        'targetAccountId': targetAccountId,
        'transactionId': txId,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 4. Notification pour tous si action de membre du bureau
    await NotificationService.notifyIfBureauAction(
      actorUserId: repayment.recordedByUserId,
      actorName: repayment.recordedByName,
      actorRole: recorderRole,
      title: 'Remboursement d\'emprunt perçu',
      body: 'Un remboursement d\'emprunt de ${repayment.amount.toFormattedString()} a été encaissé par l\'association de la part de $borrowerName.',
      entityType: 'loan',
      entityId: loanId,
    );
  }

  @override
  Future<void> deleteLoan({
    required String loanId,
    required String adminUserId,
    required String adminName,
    required String adminRole,
  }) async {
    final docRef = _firestore.collection(AppConstants.colLoans).doc(loanId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final borrowerName = (doc.data()?['borrowerName'] as String?) ?? 'Membre';

    await docRef.delete();

    // Audit Log
    await _firestore.collection(AppConstants.colAuditLogs).doc().set({
      'userId': adminUserId,
      'userName': adminName,
      'userRole': adminRole,
      'action': 'loan.deleted',
      'entityType': 'loan',
      'entityId': loanId,
      'details': {
        'borrowerName': borrowerName,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
