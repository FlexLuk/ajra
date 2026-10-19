import '../../../core/utils/money.dart';

class FundraisingCampaign {
  final String id;
  final String title;
  final String description;
  final String? eventId;
  final String? eventTitle;
  final Money goalAmount;
  final Money collectedAmount;
  final DateTime startDate;
  final DateTime? deadline;
  final String organizerUserId;
  final String organizerName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FundraisingCampaign({
    required this.id,
    required this.title,
    required this.description,
    this.eventId,
    this.eventTitle,
    required this.goalAmount,
    this.collectedAmount = const Money.zero(),
    required this.startDate,
    this.deadline,
    required this.organizerUserId,
    required this.organizerName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressPercentage {
    if (goalAmount.isZero) return 0.0;
    final pct = (collectedAmount.cents / goalAmount.cents) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  Money get remainingAmount {
    final rem = goalAmount - collectedAmount;
    return rem.isNegative ? const Money.zero() : rem;
  }

  factory FundraisingCampaign.fromJson(Map<String, dynamic> json, String docId) {
    return FundraisingCampaign(
      id: docId,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      eventId: json['eventId'] as String?,
      eventTitle: json['eventTitle'] as String?,
      goalAmount: Money.fromCents((json['goalAmountCents'] as num?)?.toInt() ?? 0),
      collectedAmount: Money.fromCents((json['collectedAmountCents'] as num?)?.toInt() ?? 0),
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? ''),
      organizerUserId: (json['organizerUserId'] as String?) ?? '',
      organizerName: (json['organizerName'] as String?) ?? '',
      isActive: (json['isActive'] as bool?) ?? true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'goalAmountCents': goalAmount.cents,
      'collectedAmountCents': collectedAmount.cents,
      'startDate': startDate.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'organizerUserId': organizerUserId,
      'organizerName': organizerName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class FundraisingContribution {
  final String id;
  final String campaignId;
  final String campaignTitle;
  final String userId;
  final String contributorName;
  final Money amount;
  final String paymentMode;
  final String reference;
  final String? proofUrl;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verifiedByUserId;
  final String? verifiedByName;
  final bool isRejected;
  final String? rejectionReason;
  final String? financialTransactionId;
  final DateTime createdAt;

  const FundraisingContribution({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.userId,
    required this.contributorName,
    required this.amount,
    required this.paymentMode,
    required this.reference,
    this.proofUrl,
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedByUserId,
    this.verifiedByName,
    this.isRejected = false,
    this.rejectionReason,
    this.financialTransactionId,
    required this.createdAt,
  });

  factory FundraisingContribution.fromJson(Map<String, dynamic> json, String docId) {
    return FundraisingContribution(
      id: docId,
      campaignId: (json['campaignId'] as String?) ?? '',
      campaignTitle: (json['campaignTitle'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      contributorName: (json['contributorName'] as String?) ?? '',
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      paymentMode: (json['paymentMode'] as String?) ?? 'Hors-app',
      reference: (json['reference'] as String?) ?? '',
      proofUrl: json['proofUrl'] as String?,
      isVerified: (json['isVerified'] as bool?) ?? false,
      verifiedAt: DateTime.tryParse(json['verifiedAt']?.toString() ?? ''),
      verifiedByUserId: json['verifiedByUserId'] as String?,
      verifiedByName: json['verifiedByName'] as String?,
      isRejected: (json['isRejected'] as bool?) ?? false,
      rejectionReason: json['rejectionReason'] as String?,
      financialTransactionId: json['financialTransactionId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaignId': campaignId,
      'campaignTitle': campaignTitle,
      'userId': userId,
      'contributorName': contributorName,
      'amountCents': amount.cents,
      'paymentMode': paymentMode,
      'reference': reference,
      'proofUrl': proofUrl,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedByUserId': verifiedByUserId,
      'verifiedByName': verifiedByName,
      'isRejected': isRejected,
      'rejectionReason': rejectionReason,
      'financialTransactionId': financialTransactionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
