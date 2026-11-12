import '../../../core/utils/money.dart';

enum LoanStatus {
  pending('En attente'),
  approved('En cours'),
  repaid('Remboursé'),
  overdue('En retard'),
  rejected('Rejeté');

  final String label;
  const LoanStatus(this.label);

  static LoanStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
      case 'en_cours':
      case 'active':
        return LoanStatus.approved;
      case 'repaid':
      case 'remboursé':
      case 'solde':
        return LoanStatus.repaid;
      case 'overdue':
      case 'en_retard':
        return LoanStatus.overdue;
      case 'rejected':
      case 'rejete':
      case 'rejeté':
        return LoanStatus.rejected;
      case 'pending':
      case 'en_attente':
      default:
        return LoanStatus.pending;
    }
  }

  bool get isPending => this == LoanStatus.pending;
  bool get isApproved => this == LoanStatus.approved;
  bool get isRepaid => this == LoanStatus.repaid;
  bool get isOverdue => this == LoanStatus.overdue;
  bool get isRejected => this == LoanStatus.rejected;
}

class MemberLoan {
  final String id;
  final String borrowerUserId;
  final String borrowerName;
  final String? borrowerPhone;
  final Money amount;
  final Money amountRepaid;
  final String purpose;
  final DateTime requestedAt;
  final DateTime dueDate;
  final DateTime? approvedAt;
  final String? approvedByUserId;
  final String? approvedByName;
  final LoanStatus status;
  final String? accountId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemberLoan({
    required this.id,
    required this.borrowerUserId,
    required this.borrowerName,
    this.borrowerPhone,
    required this.amount,
    this.amountRepaid = const Money.zero(),
    required this.purpose,
    required this.requestedAt,
    required this.dueDate,
    this.approvedAt,
    this.approvedByUserId,
    this.approvedByName,
    this.status = LoanStatus.pending,
    this.accountId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Money get remainingAmount {
    if (status == LoanStatus.repaid) return const Money.zero();
    final rem = amount - amountRepaid;
    return rem.isNegative ? const Money.zero() : rem;
  }

  bool get isOverdueCalculated {
    if (status == LoanStatus.repaid || status == LoanStatus.rejected) return false;
    return DateTime.now().isAfter(dueDate) && remainingAmount.cents > 0;
  }

  double get repaymentProgress {
    if (amount.cents <= 0) return 1.0;
    return (amountRepaid.cents / amount.cents).clamp(0.0, 1.0);
  }

  factory MemberLoan.fromJson(Map<String, dynamic> json, String docId) {
    return MemberLoan(
      id: docId,
      borrowerUserId: (json['borrowerUserId'] as String?) ?? '',
      borrowerName: (json['borrowerName'] as String?) ?? 'Membre',
      borrowerPhone: json['borrowerPhone'] as String?,
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      amountRepaid: Money.fromCents((json['amountRepaidCents'] as num?)?.toInt() ?? 0),
      purpose: (json['purpose'] as String?) ?? 'Solidarité',
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      approvedAt: DateTime.tryParse(json['approvedAt']?.toString() ?? ''),
      approvedByUserId: json['approvedByUserId'] as String?,
      approvedByName: json['approvedByName'] as String?,
      status: LoanStatus.fromString(json['status'] as String?),
      accountId: json['accountId'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'borrowerUserId': borrowerUserId,
      'borrowerName': borrowerName,
      'borrowerPhone': borrowerPhone,
      'amountCents': amount.cents,
      'amountRepaidCents': amountRepaid.cents,
      'purpose': purpose,
      'requestedAt': requestedAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedByUserId': approvedByUserId,
      'approvedByName': approvedByName,
      'status': status.name,
      'accountId': accountId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MemberLoan copyWith({
    String? borrowerUserId,
    String? borrowerName,
    String? borrowerPhone,
    Money? amount,
    Money? amountRepaid,
    String? purpose,
    DateTime? requestedAt,
    DateTime? dueDate,
    DateTime? approvedAt,
    String? approvedByUserId,
    String? approvedByName,
    LoanStatus? status,
    String? accountId,
    String? notes,
    DateTime? updatedAt,
  }) {
    return MemberLoan(
      id: id,
      borrowerUserId: borrowerUserId ?? this.borrowerUserId,
      borrowerName: borrowerName ?? this.borrowerName,
      borrowerPhone: borrowerPhone ?? this.borrowerPhone,
      amount: amount ?? this.amount,
      amountRepaid: amountRepaid ?? this.amountRepaid,
      purpose: purpose ?? this.purpose,
      requestedAt: requestedAt ?? this.requestedAt,
      dueDate: dueDate ?? this.dueDate,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedByName: approvedByName ?? this.approvedByName,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class LoanRepayment {
  final String id;
  final String loanId;
  final Money amount;
  final DateTime repaymentDate;
  final String paymentMode;
  final String reference;
  final String recordedByUserId;
  final String recordedByName;
  final String? accountId;
  final String? notes;
  final DateTime createdAt;

  const LoanRepayment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.repaymentDate,
    required this.paymentMode,
    required this.reference,
    required this.recordedByUserId,
    required this.recordedByName,
    this.accountId,
    this.notes,
    required this.createdAt,
  });

  factory LoanRepayment.fromJson(Map<String, dynamic> json, String docId) {
    return LoanRepayment(
      id: docId,
      loanId: (json['loanId'] as String?) ?? '',
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      repaymentDate: DateTime.tryParse(json['repaymentDate']?.toString() ?? '') ?? DateTime.now(),
      paymentMode: (json['paymentMode'] as String?) ?? 'Espèces',
      reference: (json['reference'] as String?) ?? '',
      recordedByUserId: (json['recordedByUserId'] as String?) ?? '',
      recordedByName: (json['recordedByName'] as String?) ?? 'Inconnu',
      accountId: json['accountId'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loanId': loanId,
      'amountCents': amount.cents,
      'repaymentDate': repaymentDate.toIso8601String(),
      'paymentMode': paymentMode,
      'reference': reference,
      'recordedByUserId': recordedByUserId,
      'recordedByName': recordedByName,
      'accountId': accountId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
