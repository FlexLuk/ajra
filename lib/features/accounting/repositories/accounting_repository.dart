import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';
import '../../audit/models/audit_log_entry.dart';
import '../models/financial_account.dart';
import '../models/financial_transaction.dart';

abstract class BaseAccountingRepository {
  Stream<List<FinancialAccount>> watchAccounts();
  Future<List<FinancialAccount>> getAccounts();
  Stream<List<FinancialTransaction>> watchTransactions({
    TransactionType? typeFilter,
    TransactionStatus? statusFilter,
    String? categoryFilter,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<void> createTransaction(FinancialTransaction tx);
  Future<void> validateTransaction({
    required String transactionId,
    required String validatorUserId,
    required String validatorName,
    required String validatorRole,
  });
  Future<void> cancelTransaction({
    required String transactionId,
    required String reason,
    required String cancelerUserId,
    required String cancelerName,
    required String cancelerRole,
  });
  Future<Map<String, dynamic>> getTreasurySummary();
}

class FirestoreAccountingRepository implements BaseAccountingRepository {
  final FirebaseFirestore _firestore;

  FirestoreAccountingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _accountsCol =>
      _firestore.collection(AppConstants.colFinancialAccounts);

  CollectionReference<Map<String, dynamic>> get _transactionsCol =>
      _firestore.collection(AppConstants.colFinancialTransactions);

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _firestore.collection(AppConstants.colAuditLogs);

  @override
  Stream<List<FinancialAccount>> watchAccounts() {
    return _accountsCol.snapshots().map((snapshot) {
      final defaultList = [
        FinancialAccount.cashDefault(),
        FinancialAccount.bankDefault(),
        FinancialAccount.juiceDefault(),
      ];
      if (snapshot.docs.isEmpty) {
        return defaultList;
      }
      final existingAccounts = snapshot.docs
          .map((doc) => FinancialAccount.fromJson(doc.data(), doc.id))
          .toList();

      // Ensure all 3 accounts exist in the list
      final accountsById = {for (final a in existingAccounts) a.id: a};
      for (final defAcc in defaultList) {
        if (!accountsById.containsKey(defAcc.id)) {
          existingAccounts.add(defAcc);
        }
      }
      return existingAccounts;
    });
  }

  @override
  Future<List<FinancialAccount>> getAccounts() async {
    final snapshot = await _accountsCol.get();
    final defaultList = [
      FinancialAccount.cashDefault(),
      FinancialAccount.bankDefault(),
      FinancialAccount.juiceDefault(),
    ];
    if (snapshot.docs.isEmpty) {
      return defaultList;
    }
    final existingAccounts = snapshot.docs
        .map((doc) => FinancialAccount.fromJson(doc.data(), doc.id))
        .toList();

    final accountsById = {for (final a in existingAccounts) a.id: a};
    for (final defAcc in defaultList) {
      if (!accountsById.containsKey(defAcc.id)) {
        existingAccounts.add(defAcc);
      }
    }
    return existingAccounts;
  }

  @override
  Stream<List<FinancialTransaction>> watchTransactions({
    TransactionType? typeFilter,
    TransactionStatus? statusFilter,
    String? categoryFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _transactionsCol.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => FinancialTransaction.fromJson(doc.data(), doc.id))
          .toList();

      if (typeFilter != null) {
        list = list.where((tx) => tx.type == typeFilter).toList();
      }
      if (statusFilter != null) {
        list = list.where((tx) => tx.status == statusFilter).toList();
      }
      if (categoryFilter != null) {
        list = list.where((tx) => tx.category == categoryFilter).toList();
      }
      if (startDate != null) {
        list = list.where((tx) => tx.date.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        list = list.where((tx) => tx.date.isBefore(endDate)).toList();
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Future<void> createTransaction(FinancialTransaction tx) async {
    final docRef = _transactionsCol.doc(tx.id);
    await docRef.set(tx.toJson());

    // Audit log
    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: tx.createdByUserId,
      userName: tx.createdByName,
      userRole: 'BUREAU',
      action: 'transaction.created',
      entityType: 'transaction',
      entityId: tx.id,
      details: {
        'type': tx.type.name,
        'category': tx.category,
        'amountCents': tx.amount.cents,
        'status': tx.status.name,
        'accountId': tx.accountId,
      },
      timestamp: DateTime.now(),
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> validateTransaction({
    required String transactionId,
    required String validatorUserId,
    required String validatorName,
    required String validatorRole,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final txDocRef = _transactionsCol.doc(transactionId);
      final txSnapshot = await transaction.get(txDocRef);

      if (!txSnapshot.exists) {
        throw Exception('Transaction introuvable');
      }

      final tx = FinancialTransaction.fromJson(txSnapshot.data()!, transactionId);
      if (tx.status != TransactionStatus.pending) {
        throw Exception('Cette opération n\'est plus en attente');
      }

      // Récupérer le compte
      final accountDocRef = _accountsCol.doc(tx.accountId);
      final accountSnapshot = await transaction.get(accountDocRef);

      int currentCents = 0;
      if (accountSnapshot.exists) {
        currentCents = (accountSnapshot.data()!['currentBalanceCents'] as num?)?.toInt() ?? 0;
      }

      int newAccountCents = currentCents;
      if (tx.type == TransactionType.income) {
        newAccountCents += tx.amount.cents;
      } else if (tx.type == TransactionType.expense) {
        newAccountCents -= tx.amount.cents;
      } else if (tx.type == TransactionType.transfer && tx.targetAccountId != null) {
        // Débiter la source
        newAccountCents -= tx.amount.cents;
        // Créditer la cible
        final targetDocRef = _accountsCol.doc(tx.targetAccountId!);
        final targetSnapshot = await transaction.get(targetDocRef);
        final targetCurrentCents =
            (targetSnapshot.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
        transaction.set(targetDocRef, {
          'currentBalanceCents': targetCurrentCents + tx.amount.cents,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }

      // Mettre à jour le compte source
      transaction.set(accountDocRef, {
        'currentBalanceCents': newAccountCents,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Mettre à jour la transaction
      transaction.update(txDocRef, {
        'status': TransactionStatus.validated.name,
        'validatedByUserId': validatorUserId,
        'validatedByName': validatorName,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Audit Log
      final auditDocRef = _auditCol.doc();
      transaction.set(auditDocRef, {
        'userId': validatorUserId,
        'userName': validatorName,
        'userRole': validatorRole,
        'action': 'transaction.validated',
        'entityType': 'transaction',
        'entityId': transactionId,
        'details': {
          'type': tx.type.name,
          'amountCents': tx.amount.cents,
          'newAccountBalanceCents': newAccountCents,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Future<void> cancelTransaction({
    required String transactionId,
    required String reason,
    required String cancelerUserId,
    required String cancelerName,
    required String cancelerRole,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final txDocRef = _transactionsCol.doc(transactionId);
      final txSnapshot = await transaction.get(txDocRef);

      if (!txSnapshot.exists) throw Exception('Transaction introuvable');
      final tx = FinancialTransaction.fromJson(txSnapshot.data()!, transactionId);

      if (tx.status == TransactionStatus.cancelled) {
        throw Exception('Cette opération a déjà été annulée');
      }

      // Si l'opération avait été validée, on contre-passe son effet sur le compte
      if (tx.status == TransactionStatus.validated) {
        final accountDocRef = _accountsCol.doc(tx.accountId);
        final accountSnapshot = await transaction.get(accountDocRef);
        final currentCents =
            (accountSnapshot.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;

        int correctedCents = currentCents;
        if (tx.type == TransactionType.income) {
          correctedCents -= tx.amount.cents; // annuler recette
        } else if (tx.type == TransactionType.expense) {
          correctedCents += tx.amount.cents; // annuler dépense
        }

        transaction.set(accountDocRef, {
          'currentBalanceCents': correctedCents,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }

      transaction.update(txDocRef, {
        'status': TransactionStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Audit
      final auditDocRef = _auditCol.doc();
      transaction.set(auditDocRef, {
        'userId': cancelerUserId,
        'userName': cancelerName,
        'userRole': cancelerRole,
        'action': 'transaction.cancelled',
        'entityType': 'transaction',
        'entityId': transactionId,
        'details': {'reason': reason},
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Future<Map<String, dynamic>> getTreasurySummary() async {
    final snapshot = await _transactionsCol.get();
    final allTxs = snapshot.docs
        .map((doc) => FinancialTransaction.fromJson(doc.data(), doc.id))
        .toList();

    int totalIncomeCents = 0;
    int totalExpenseCents = 0;
    int pendingIncomeCents = 0;
    int pendingExpenseCents = 0;

    final incomeByCategory = <String, int>{};
    final expenseByCategory = <String, int>{};

    for (final tx in allTxs) {
      if (tx.status == TransactionStatus.validated) {
        if (tx.type == TransactionType.income) {
          totalIncomeCents += tx.amount.cents;
          incomeByCategory[tx.category] =
              (incomeByCategory[tx.category] ?? 0) + tx.amount.cents;
        } else if (tx.type == TransactionType.expense) {
          totalExpenseCents += tx.amount.cents;
          expenseByCategory[tx.category] =
              (expenseByCategory[tx.category] ?? 0) + tx.amount.cents;
        }
      } else if (tx.status == TransactionStatus.pending) {
        if (tx.type == TransactionType.income) {
          pendingIncomeCents += tx.amount.cents;
        } else if (tx.type == TransactionType.expense) {
          pendingExpenseCents += tx.amount.cents;
        }
      }
    }

    final netBalanceCents = totalIncomeCents - totalExpenseCents;

    return {
      'totalIncome': Money.fromCents(totalIncomeCents),
      'totalExpense': Money.fromCents(totalExpenseCents),
      'netBalance': Money.fromCents(netBalanceCents),
      'pendingIncome': Money.fromCents(pendingIncomeCents),
      'pendingExpense': Money.fromCents(pendingExpenseCents),
      'incomeByCategory': incomeByCategory,
      'expenseByCategory': expenseByCategory,
    };
  }
}
