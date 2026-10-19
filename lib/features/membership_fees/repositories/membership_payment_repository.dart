import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../audit/models/audit_log_entry.dart';
import '../models/membership_fee_config.dart';
import '../models/membership_payment.dart';

abstract class BaseMembershipPaymentRepository {
  Stream<MembershipFeeConfig> watchFeeConfig();
  Future<MembershipFeeConfig> getFeeConfig();
  Future<void> updateFeeConfig(MembershipFeeConfig config);

  Stream<MembershipPayment?> watchPayment(String userId);
  Future<MembershipPayment?> getPayment(String userId);
  Stream<List<MembershipPayment>> watchAllPayments({bool? onlyPending});

  Future<void> declarePayment({
    required String userId,
    required String memberNumber,
    required String memberName,
    required Money amount,
    required String paymentMode,
    required String transactionReference,
    String? proofUrl,
    String? notes,
  });

  Future<void> verifyPayment({
    required String paymentId,
    required String verifierUserId,
    required String verifierName,
    required String verifierRole,
    required bool approve,
    String? notes,
    String accountId = AppConstants.accountCash,
  });
}

class FirestoreMembershipPaymentRepository implements BaseMembershipPaymentRepository {
  final FirebaseFirestore _firestore;

  FirestoreMembershipPaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _paymentsCol =>
      _firestore.collection(AppConstants.colMembershipPayments);

  CollectionReference<Map<String, dynamic>> get _configCol =>
      _firestore.collection(AppConstants.colMembershipFeeConfigs);

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _firestore.collection(AppConstants.colFinancialTransactions);

  CollectionReference<Map<String, dynamic>> get _accountsCol =>
      _firestore.collection(AppConstants.colFinancialAccounts);

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _firestore.collection(AppConstants.colAuditLogs);

  @override
  Stream<MembershipFeeConfig> watchFeeConfig() {
    return _configCol.doc('current').snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return MembershipFeeConfig.defaultConfig();
      }
      return MembershipFeeConfig.fromJson(doc.data()!);
    });
  }

  @override
  Future<MembershipFeeConfig> getFeeConfig() async {
    final doc = await _configCol.doc('current').get();
    if (!doc.exists || doc.data() == null) {
      return MembershipFeeConfig.defaultConfig();
    }
    return MembershipFeeConfig.fromJson(doc.data()!);
  }

  @override
  Future<void> updateFeeConfig(MembershipFeeConfig config) async {
    await _configCol.doc('current').set(config.toJson());
  }

  @override
  Stream<MembershipPayment?> watchPayment(String userId) {
    return _paymentsCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MembershipPayment.fromJson(doc.data()!, doc.id);
    });
  }

  @override
  Future<MembershipPayment?> getPayment(String userId) async {
    final doc = await _paymentsCol.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return MembershipPayment.fromJson(doc.data()!, doc.id);
  }

  @override
  Stream<List<MembershipPayment>> watchAllPayments({bool? onlyPending}) {
    Query<Map<String, dynamic>> query = _paymentsCol.orderBy('updatedAt', descending: true);
    if (onlyPending == true) {
      query = query.where('isDeclared', isEqualTo: true).where('isVerified', isEqualTo: false);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MembershipPayment.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> declarePayment({
    required String userId,
    required String memberNumber,
    required String memberName,
    required Money amount,
    required String paymentMode,
    required String transactionReference,
    String? proofUrl,
    String? notes,
  }) async {
    final now = DateTime.now();
    final payment = MembershipPayment(
      id: userId,
      userId: userId,
      memberNumber: memberNumber,
      memberName: memberName,
      amount: amount,
      paymentMode: paymentMode,
      transactionReference: transactionReference,
      proofUrl: proofUrl,
      isDeclared: true,
      declaredAt: now,
      isVerified: false,
      isRejected: false,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await _paymentsCol.doc(userId).set(payment.toJson(), SetOptions(merge: true));

    // Audit Log
    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: userId,
      userName: memberName,
      userRole: 'MEMBRE',
      action: 'payment.membership_fee.declared',
      entityType: 'membershipPayment',
      entityId: userId,
      details: {
        'amountCents': amount.cents,
        'mode': paymentMode,
        'reference': transactionReference,
      },
      timestamp: now,
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> verifyPayment({
    required String paymentId,
    required String verifierUserId,
    required String verifierName,
    required String verifierRole,
    required bool approve,
    String? notes,
    String accountId = AppConstants.accountCash,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final paymentDocRef = _paymentsCol.doc(paymentId);
      final paymentSnapshot = await transaction.get(paymentDocRef);

      if (!paymentSnapshot.exists) {
        throw Exception('Dossier de paiement introuvable');
      }

      final payment = MembershipPayment.fromJson(paymentSnapshot.data()!, paymentId);

      // Règle métier stricte : Ne permets pas à un utilisateur de confirmer son propre paiement
      if (payment.userId == verifierUserId) {
        throw Exception('Règle de séparation des fonctions : Vous ne pouvez pas confirmer votre propre paiement.');
      }

      final now = DateTime.now();

      if (approve) {
        // 1. Créer UNE SEULE écriture financière validée
        final txId = const Uuid().v4();
        final txDocRef = _txCol.doc(txId);

        final financialTx = FinancialTransaction(
          id: txId,
          type: TransactionType.income,
          category: 'Droits d\'adhésion',
          amount: payment.amount,
          date: now,
          description: 'Droit d\'adhésion membre ${payment.memberName} (${payment.memberNumber})',
          paymentMode: payment.paymentMode ?? 'Hors-application',
          reference: payment.transactionReference ?? 'REF-ADH-$paymentId',
          receiptUrl: payment.proofUrl,
          accountId: accountId,
          createdByUserId: verifierUserId,
          createdByName: verifierName,
          validatedByUserId: verifierUserId,
          validatedByName: verifierName,
          status: TransactionStatus.validated,
          linkedEntityType: 'membership_fee',
          linkedEntityId: paymentId,
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(txDocRef, financialTx.toJson());

        // 2. Mettre à jour le solde du compte financier
        final accountDocRef = _accountsCol.doc(accountId);
        final accountSnapshot = await transaction.get(accountDocRef);
        final currentCents = (accountSnapshot.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
        transaction.set(accountDocRef, {
          'currentBalanceCents': currentCents + payment.amount.cents,
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));

        // 3. Mettre à jour le statut du paiement d'adhésion
        transaction.update(paymentDocRef, {
          'isVerified': true,
          'isRejected': false,
          'verifiedAt': now.toIso8601String(),
          'verifiedByUserId': verifierUserId,
          'verifiedByName': verifierName,
          'notes': notes ?? payment.notes,
          'financialTransactionId': txId,
          'updatedAt': now.toIso8601String(),
        });
      } else {
        // Rejeter la déclaration
        transaction.update(paymentDocRef, {
          'isVerified': false,
          'isRejected': true,
          'rejectionReason': notes ?? 'Paiement non constaté sur le compte de l\'association.',
          'updatedAt': now.toIso8601String(),
        });
      }

      // 4. Audit Log
      final auditDocRef = _auditCol.doc();
      transaction.set(auditDocRef, {
        'userId': verifierUserId,
        'userName': verifierName,
        'userRole': verifierRole,
        'action': approve ? 'payment.membership_fee.verified' : 'payment.membership_fee.rejected',
        'entityType': 'membershipPayment',
        'entityId': paymentId,
        'details': {
          'approved': approve,
          'amountCents': payment.amount.cents,
          'notes': notes ?? '',
        },
        'timestamp': now.toIso8601String(),
      });
    });
  }
}
