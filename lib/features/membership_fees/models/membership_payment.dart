import '../../../core/utils/money.dart';

class MembershipPayment {
  final String id;
  final String userId;
  final String memberNumber;
  final String memberName;
  final Money amount;
  final String? paymentMode; // ex: "Espèces", "Virement MCB", "Virement SBM"
  final String? transactionReference;
  final String? proofUrl;
  final bool isDeclared;
  final DateTime? declaredAt;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verifiedByUserId;
  final String? verifiedByName;
  final bool isRejected;
  final String? rejectionReason;
  final String? notes;
  final String? financialTransactionId; // Lien vers l'écriture comptable unique
  final DateTime createdAt;
  final DateTime updatedAt;

  const MembershipPayment({
    required this.id,
    required this.userId,
    required this.memberNumber,
    required this.memberName,
    required this.amount,
    this.paymentMode,
    this.transactionReference,
    this.proofUrl,
    this.isDeclared = false,
    this.declaredAt,
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedByUserId,
    this.verifiedByName,
    this.isRejected = false,
    this.rejectionReason,
    this.notes,
    this.financialTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPendingVerification => isDeclared && !isVerified && !isRejected;

  factory MembershipPayment.fromJson(Map<String, dynamic> json, String docId) {
    return MembershipPayment(
      id: docId,
      userId: (json['userId'] as String?) ?? docId,
      memberNumber: (json['memberNumber'] as String?) ?? '',
      memberName: (json['memberName'] as String?) ?? '',
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      paymentMode: json['paymentMode'] as String?,
      transactionReference: json['transactionReference'] as String?,
      proofUrl: json['proofUrl'] as String?,
      isDeclared: (json['isDeclared'] as bool?) ?? false,
      declaredAt: DateTime.tryParse(json['declaredAt']?.toString() ?? ''),
      isVerified: (json['isVerified'] as bool?) ?? false,
      verifiedAt: DateTime.tryParse(json['verifiedAt']?.toString() ?? ''),
      verifiedByUserId: json['verifiedByUserId'] as String?,
      verifiedByName: json['verifiedByName'] as String?,
      isRejected: (json['isRejected'] as bool?) ?? false,
      rejectionReason: json['rejectionReason'] as String?,
      notes: json['notes'] as String?,
      financialTransactionId: json['financialTransactionId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'memberNumber': memberNumber,
      'memberName': memberName,
      'amountCents': amount.cents,
      'paymentMode': paymentMode,
      'transactionReference': transactionReference,
      'proofUrl': proofUrl,
      'isDeclared': isDeclared,
      'declaredAt': declaredAt?.toIso8601String(),
      'isVerified': isVerified,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedByUserId': verifiedByUserId,
      'verifiedByName': verifiedByName,
      'isRejected': isRejected,
      'rejectionReason': rejectionReason,
      'notes': notes,
      'financialTransactionId': financialTransactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
