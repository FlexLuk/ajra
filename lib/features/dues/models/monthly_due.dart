import '../../../core/utils/money.dart';

enum DueStatus {
  pending('À payer'),
  declared('Déclaré'),
  inReview('En vérification'),
  paid('Payé'),
  partiallyPaid('Partiellement payé'),
  overdue('En retard'),
  exempt('Exonéré');

  final String label;
  const DueStatus(this.label);

  static DueStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'declared':
        return DueStatus.declared;
      case 'inreview':
      case 'in_review':
        return DueStatus.inReview;
      case 'paid':
        return DueStatus.paid;
      case 'partiallypaid':
      case 'partially_paid':
        return DueStatus.partiallyPaid;
      case 'overdue':
        return DueStatus.overdue;
      case 'exempt':
        return DueStatus.exempt;
      case 'pending':
      default:
        return DueStatus.pending;
    }
  }

  bool get isPaid => this == DueStatus.paid;
  bool get isPending => this == DueStatus.pending;
  bool get isDeclared => this == DueStatus.declared;
  bool get isInReview => this == DueStatus.inReview;
  bool get isOverdue => this == DueStatus.overdue;
  bool get isPartiallyPaid => this == DueStatus.partiallyPaid;
  bool get isExempt => this == DueStatus.exempt;
}

class MonthlyDue {
  final String id; // Déterministe: ex: "${userId}_2026_03"
  final String userId;
  final String memberNumber;
  final String memberName;
  final int periodYear;
  final int periodMonth;
  final String periodLabel; // ex: "Mars 2026"
  final Money amount;
  final Money amountPaid;
  final DueStatus status;
  final String? declaredPaymentMode;
  final String? transactionReference;
  final String? proofUrl;
  final DateTime? declaredAt;
  final DateTime? verifiedAt;
  final String? verifiedByUserId;
  final String? verifiedByName;
  final String? notes;
  final String? financialTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MonthlyDue({
    required this.id,
    required this.userId,
    required this.memberNumber,
    required this.memberName,
    required this.periodYear,
    required this.periodMonth,
    required this.periodLabel,
    required this.amount,
    this.amountPaid = const Money.zero(),
    this.status = DueStatus.pending,
    this.declaredPaymentMode,
    this.transactionReference,
    this.proofUrl,
    this.declaredAt,
    this.verifiedAt,
    this.verifiedByUserId,
    this.verifiedByName,
    this.notes,
    this.financialTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  Money get remainingAmount {
    if (status == DueStatus.paid || status == DueStatus.exempt) return const Money.zero();
    final rem = amount - amountPaid;
    return rem.isNegative ? const Money.zero() : rem;
  }

  bool get isOverdueCalculated {
    if (status == DueStatus.paid || status == DueStatus.exempt) return false;
    final now = DateTime.now();
    final dueEndDate = DateTime(periodYear, periodMonth + 1, 0); // Dernier jour du mois échu
    return now.isAfter(dueEndDate);
  }

  factory MonthlyDue.fromJson(Map<String, dynamic> json, String docId) {
    return MonthlyDue(
      id: docId,
      userId: (json['userId'] as String?) ?? '',
      memberNumber: (json['memberNumber'] as String?) ?? '',
      memberName: (json['memberName'] as String?) ?? '',
      periodYear: (json['periodYear'] as num?)?.toInt() ?? 2026,
      periodMonth: (json['periodMonth'] as num?)?.toInt() ?? 1,
      periodLabel: (json['periodLabel'] as String?) ?? '',
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      amountPaid: Money.fromCents((json['amountPaidCents'] as num?)?.toInt() ?? 0),
      status: DueStatus.fromString(json['status'] as String?),
      declaredPaymentMode: json['declaredPaymentMode'] as String?,
      transactionReference: json['transactionReference'] as String?,
      proofUrl: json['proofUrl'] as String?,
      declaredAt: DateTime.tryParse(json['declaredAt']?.toString() ?? ''),
      verifiedAt: DateTime.tryParse(json['verifiedAt']?.toString() ?? ''),
      verifiedByUserId: json['verifiedByUserId'] as String?,
      verifiedByName: json['verifiedByName'] as String?,
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
      'periodYear': periodYear,
      'periodMonth': periodMonth,
      'periodLabel': periodLabel,
      'amountCents': amount.cents,
      'amountPaidCents': amountPaid.cents,
      'status': status.name,
      'declaredPaymentMode': declaredPaymentMode,
      'transactionReference': transactionReference,
      'proofUrl': proofUrl,
      'declaredAt': declaredAt?.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedByUserId': verifiedByUserId,
      'verifiedByName': verifiedByName,
      'notes': notes,
      'financialTransactionId': financialTransactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
