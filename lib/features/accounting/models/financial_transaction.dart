import '../../../core/utils/money.dart';

enum TransactionType {
  income('Recette'),
  expense('Dépense'),
  transfer('Transfert interne');

  final String label;
  const TransactionType(this.label);

  static TransactionType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'expense':
      case 'dépense':
        return TransactionType.expense;
      case 'transfer':
      case 'transfert':
        return TransactionType.transfer;
      case 'income':
      case 'recette':
      default:
        return TransactionType.income;
    }
  }

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;
  bool get isTransfer => this == TransactionType.transfer;
}

enum TransactionStatus {
  pending('En attente'),
  validated('Validée'),
  rejected('Rejetée'),
  cancelled('Annulée');

  final String label;
  const TransactionStatus(this.label);

  static TransactionStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'validated':
      case 'validée':
        return TransactionStatus.validated;
      case 'rejected':
      case 'rejetée':
        return TransactionStatus.rejected;
      case 'cancelled':
      case 'annulée':
        return TransactionStatus.cancelled;
      case 'pending':
      case 'en attente':
      default:
        return TransactionStatus.pending;
    }
  }

  bool get isPending => this == TransactionStatus.pending;
  bool get isValidated => this == TransactionStatus.validated;
  bool get isRejected => this == TransactionStatus.rejected;
  bool get isCancelled => this == TransactionStatus.cancelled;
}

class FinancialTransaction {
  final String id;
  final TransactionType type;
  final String category;
  final Money amount;
  final DateTime date;
  final String description;
  final String paymentMode;
  final String reference;
  final String? receiptUrl;
  final String accountId;
  final String? targetAccountId; // Pour les transferts internes
  final String createdByUserId;
  final String createdByName;
  final String? validatedByUserId;
  final String? validatedByName;
  final TransactionStatus status;
  final String? linkedEntityType; // 'membership_fee', 'dues', 'fundraising', 'event'
  final String? linkedEntityId;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? reversalTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    required this.paymentMode,
    required this.reference,
    this.receiptUrl,
    required this.accountId,
    this.targetAccountId,
    required this.createdByUserId,
    required this.createdByName,
    this.validatedByUserId,
    this.validatedByName,
    this.status = TransactionStatus.pending,
    this.linkedEntityType,
    this.linkedEntityId,
    this.cancellationReason,
    this.cancelledAt,
    this.reversalTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get affectsOfficialBalance => status == TransactionStatus.validated;

  factory FinancialTransaction.fromJson(Map<String, dynamic> json, String docId) {
    return FinancialTransaction(
      id: docId,
      type: TransactionType.fromString(json['type'] as String?),
      category: (json['category'] as String?) ?? 'Autre',
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      description: (json['description'] as String?) ?? '',
      paymentMode: (json['paymentMode'] as String?) ?? 'Espèces',
      reference: (json['reference'] as String?) ?? '',
      receiptUrl: json['receiptUrl'] as String?,
      accountId: (json['accountId'] as String?) ?? '',
      targetAccountId: json['targetAccountId'] as String?,
      createdByUserId: (json['createdByUserId'] as String?) ?? '',
      createdByName: (json['createdByName'] as String?) ?? 'Inconnu',
      validatedByUserId: json['validatedByUserId'] as String?,
      validatedByName: json['validatedByName'] as String?,
      status: TransactionStatus.fromString(json['status'] as String?),
      linkedEntityType: json['linkedEntityType'] as String?,
      linkedEntityId: json['linkedEntityId'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cancelledAt: DateTime.tryParse(json['cancelledAt']?.toString() ?? ''),
      reversalTransactionId: json['reversalTransactionId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'category': category,
      'amountCents': amount.cents,
      'date': date.toIso8601String(),
      'description': description,
      'paymentMode': paymentMode,
      'reference': reference,
      'receiptUrl': receiptUrl,
      'accountId': accountId,
      'targetAccountId': targetAccountId,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'validatedByUserId': validatedByUserId,
      'validatedByName': validatedByName,
      'status': status.name,
      'linkedEntityType': linkedEntityType,
      'linkedEntityId': linkedEntityId,
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'reversalTransactionId': reversalTransactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
