import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../audit/models/audit_log_entry.dart';
import '../../fundraising/models/fundraising_campaign.dart';
import '../models/event_item.dart';
import '../models/event_transaction.dart';

abstract class BaseEventsRepository {
  Stream<List<EventItem>> watchEvents();
  Future<void> createEvent(EventItem event);
  Future<void> deleteEvent(String eventId);

  Stream<List<EventParticipant>> watchParticipants(String eventId);
  Future<void> registerParticipant({
    required String eventId,
    required String userId,
    required String userName,
  });
  Future<void> unregisterParticipant({
    required String eventId,
    required String userId,
  });

  Stream<List<EventTransaction>> watchEventTransactions(String eventId);
  Future<void> addEventTransaction(EventTransaction transaction);
  Future<void> deleteEventTransaction(String eventId, String transactionId);

  // Compatibilité historique
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
  final _uuid = const Uuid();

  FirestoreEventsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<EventItem>> watchEvents() {
    return _firestore
        .collection(AppConstants.colEvents)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => EventItem.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.startDate.compareTo(b.startDate));
      return list;
    });
  }

  @override
  Future<void> createEvent(EventItem event) async {
    final eventId = event.id.isEmpty ? _uuid.v4() : event.id;
    await _firestore
        .collection(AppConstants.colEvents)
        .doc(eventId)
        .set(event.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection(AppConstants.colEvents).doc(eventId).delete();
  }

  @override
  Stream<List<EventParticipant>> watchParticipants(String eventId) {
    return _firestore
        .collection(AppConstants.colEventParticipants)
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((d) => EventParticipant.fromJson(d.data(), d.id))
          .toList();
    });
  }

  @override
  Future<void> registerParticipant({
    required String eventId,
    required String userId,
    required String userName,
  }) async {
    final docId = '${eventId}_$userId';
    await _firestore.collection(AppConstants.colEventParticipants).doc(docId).set({
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'registeredAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> unregisterParticipant({
    required String eventId,
    required String userId,
  }) async {
    final docId = '${eventId}_$userId';
    await _firestore.collection(AppConstants.colEventParticipants).doc(docId).delete();
  }

  @override
  Stream<List<EventTransaction>> watchEventTransactions(String eventId) {
    return _firestore
        .collection(AppConstants.colEventTransactions)
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((d) => EventTransaction.fromJson(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Future<void> addEventTransaction(EventTransaction transaction) async {
    final txId = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    await _firestore
        .collection(AppConstants.colEventTransactions)
        .doc(txId)
        .set(transaction.toJson());
  }

  @override
  Future<void> deleteEventTransaction(String eventId, String transactionId) async {
    await _firestore
        .collection(AppConstants.colEventTransactions)
        .doc(transactionId)
        .delete();
  }

  // Compatibilité historique
  @override
  Stream<List<FundraisingCampaign>> watchCampaigns() {
    return Stream.value([]);
  }

  @override
  Stream<List<FundraisingContribution>> watchContributions(String campaignId) {
    return Stream.value([]);
  }

  @override
  Future<void> createCampaign(FundraisingCampaign campaign) async {}

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
  }) async {}

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
  }) async {}
}
