import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../audit/models/audit_log_entry.dart';
import '../../fundraising/models/fundraising_campaign.dart';
import '../models/event_item.dart';

abstract class BaseEventsRepository {
  Stream<List<EventItem>> watchEvents();
  Future<void> createEvent(EventItem event);
  Future<void> registerParticipant({
    required String eventId,
    required String userId,
    required String userName,
  });

  Stream<List<FundraisingCampaign>> watchCampaigns();
  Stream<List<FundraisingContribution>> watchContributions(String campaignId);
  Future<void> createCampaign(FundraisingCampaign campaign);
  Future<void> declareContribution({
    required String campaignId,
    required String campaignTitle,
    required String userId,
    required String contributorName,
    required Money amount,
    required String paymentMode,
    required String reference,
    String? proofUrl,
  });
  Future<void> verifyContribution({
    required String contributionId,
    required String campaignId,
    required String verifierUserId,
    required String verifierName,
    required String verifierRole,
    required bool approve,
    String accountId = AppConstants.accountCash,
    String? rejectionReason,
  });
}

class FirestoreEventsRepository implements BaseEventsRepository {
  final FirebaseFirestore _firestore;

  FirestoreEventsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _firestore.collection(AppConstants.colEvents);

  CollectionReference<Map<String, dynamic>> get _participantsCol =>
      _firestore.collection(AppConstants.colEventParticipants);

  CollectionReference<Map<String, dynamic>> get _campaignsCol =>
      _firestore.collection(AppConstants.colFundraisingCampaigns);

  CollectionReference<Map<String, dynamic>> get _contributionsCol =>
      _firestore.collection(AppConstants.colFundraisingContributions);

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _firestore.collection(AppConstants.colFinancialTransactions);

  CollectionReference<Map<String, dynamic>> get _accountsCol =>
      _firestore.collection(AppConstants.colFinancialAccounts);

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _firestore.collection(AppConstants.colAuditLogs);

  @override
  Stream<List<EventItem>> watchEvents() {
    return _eventsCol.orderBy('startDate', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EventItem.fromJson(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> createEvent(EventItem event) async {
    await _eventsCol.doc(event.id).set(event.toJson());

    // Audit Log
    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: event.organizerUserId,
      userName: event.organizerName,
      userRole: 'BUREAU',
      action: 'event.created',
      entityType: 'event',
      entityId: event.id,
      details: {'title': event.title, 'startDate': event.startDate.toIso8601String()},
      timestamp: DateTime.now(),
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> registerParticipant({
    required String eventId,
    required String userId,
    required String userName,
  }) async {
    final docId = '${eventId}_$userId';
    await _participantsCol.doc(docId).set({
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'registeredAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Stream<List<FundraisingCampaign>> watchCampaigns() {
    return _campaignsCol.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FundraisingCampaign.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<List<FundraisingContribution>> watchContributions(String campaignId) {
    return _contributionsCol
        .where('campaignId', isEqualTo: campaignId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FundraisingContribution.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> createCampaign(FundraisingCampaign campaign) async {
    await _campaignsCol.doc(campaign.id).set(campaign.toJson());
  }

  @override
  Future<void> declareContribution({
    required String campaignId,
    required String campaignTitle,
    required String userId,
    required String contributorName,
    required Money amount,
    required String paymentMode,
    required String reference,
    String? proofUrl,
  }) async {
    final now = DateTime.now();
    final contribId = const Uuid().v4();

    final contrib = FundraisingContribution(
      id: contribId,
      campaignId: campaignId,
      campaignTitle: campaignTitle,
      userId: userId,
      contributorName: contributorName,
      amount: amount,
      paymentMode: paymentMode,
      reference: reference,
      proofUrl: proofUrl,
      isVerified: false,
      createdAt: now,
    );

    await _contributionsCol.doc(contribId).set(contrib.toJson());

    // Audit Log
    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: userId,
      userName: contributorName,
      userRole: 'MEMBRE',
      action: 'fundraising.contribution.declared',
      entityType: 'fundraisingContribution',
      entityId: contribId,
      details: {
        'campaignId': campaignId,
        'amountCents': amount.cents,
        'reference': reference,
      },
      timestamp: now,
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> verifyContribution({
    required String contributionId,
    required String campaignId,
    required String verifierUserId,
    required String verifierName,
    required String verifierRole,
    required bool approve,
    String accountId = AppConstants.accountCash,
    String? rejectionReason,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final contribDocRef = _contributionsCol.doc(contributionId);
      final contribSnapshot = await transaction.get(contribDocRef);

      if (!contribSnapshot.exists) throw Exception('Contribution introuvable');
      final contrib =
          FundraisingContribution.fromJson(contribSnapshot.data()!, contributionId);

      // Règle de séparation des fonctions: ne peut valider sa propre contribution
      if (contrib.userId == verifierUserId) {
        throw Exception('Sécurité : Vous ne pouvez pas valider votre propre contribution.');
      }

      final now = DateTime.now();

      if (approve) {
        // 1. Créer UNE SEULE transaction financière validée
        final txId = const Uuid().v4();
        final txDocRef = _txCol.doc(txId);

        final financialTx = FinancialTransaction(
          id: txId,
          type: TransactionType.income,
          category: 'Dons & Collectes',
          amount: contrib.amount,
          date: now,
          description:
              'Collecte "${contrib.campaignTitle}" - Don de ${contrib.contributorName}',
          paymentMode: contrib.paymentMode,
          reference: contrib.reference,
          receiptUrl: contrib.proofUrl,
          accountId: accountId,
          createdByUserId: verifierUserId,
          createdByName: verifierName,
          validatedByUserId: verifierUserId,
          validatedByName: verifierName,
          status: TransactionStatus.validated,
          linkedEntityType: 'fundraising',
          linkedEntityId: contributionId,
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(txDocRef, financialTx.toJson());

        // 2. Mettre à jour le solde du compte de trésorerie
        final accountDocRef = _accountsCol.doc(accountId);
        final accountSnapshot = await transaction.get(accountDocRef);
        final currentCents = (accountSnapshot.data()?['currentBalanceCents'] as num?)?.toInt() ?? 0;
        transaction.set(accountDocRef, {
          'currentBalanceCents': currentCents + contrib.amount.cents,
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));

        // 3. Mettre à jour le montant collecté de la campagne
        final campaignDocRef = _campaignsCol.doc(campaignId);
        final campaignSnapshot = await transaction.get(campaignDocRef);
        if (campaignSnapshot.exists) {
          final currentCollectedCents =
              (campaignSnapshot.data()?['collectedAmountCents'] as num?)?.toInt() ?? 0;
          transaction.update(campaignDocRef, {
            'collectedAmountCents': currentCollectedCents + contrib.amount.cents,
            'updatedAt': now.toIso8601String(),
          });
        }

        // 4. Mettre à jour la contribution
        transaction.update(contribDocRef, {
          'isVerified': true,
          'isRejected': false,
          'verifiedAt': now.toIso8601String(),
          'verifiedByUserId': verifierUserId,
          'verifiedByName': verifierName,
          'financialTransactionId': txId,
        });
      } else {
        transaction.update(contribDocRef, {
          'isVerified': false,
          'isRejected': true,
          'rejectionReason': rejectionReason ?? 'Fonds non constatés.',
        });
      }

      // 5. Audit Log
      final auditDocRef = _auditCol.doc();
      transaction.set(auditDocRef, {
        'userId': verifierUserId,
        'userName': verifierName,
        'userRole': verifierRole,
        'action': approve ? 'fundraising.contribution.verified' : 'fundraising.contribution.rejected',
        'entityType': 'fundraisingContribution',
        'entityId': contributionId,
        'details': {'amountCents': contrib.amount.cents, 'approved': approve},
        'timestamp': now.toIso8601String(),
      });
    });
  }
}
