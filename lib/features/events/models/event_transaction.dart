import '../../../core/utils/money.dart';

enum EventTransactionType {
  income('Entrée (Recette)'),
  expense('Sortie (Dépense)');

  final String label;
  const EventTransactionType(this.label);

  static EventTransactionType fromString(String? val) {
    if (val?.toLowerCase() == 'expense' || val?.toLowerCase() == 'sortie') {
      return EventTransactionType.expense;
    }
    return EventTransactionType.income;
  }

  bool get isIncome => this == EventTransactionType.income;
  bool get isExpense => this == EventTransactionType.expense;
}

class EventTransaction {
  final String id;
  final String eventId;
  final EventTransactionType type;
  final String title;
  final Money amount;
  final String category; // ex: "Courses Supermarché", "Transport / Bus", "Cotisation Sortie", "Boissons", "Location", "Autre"
  final DateTime date;
  final String paymentMode; // 'Espèces', 'Juice MCB', 'Virement', 'Autre'
  final String recordedByUserId;
  final String recordedByName;
  final String? receiptReference; // ex: "Ticket caisse Jumbo #4582"
  final String? receiptUrl;
  final String? notes;
  final DateTime createdAt;

  const EventTransaction({
    required this.id,
    required this.eventId,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.paymentMode,
    required this.recordedByUserId,
    required this.recordedByName,
    this.receiptReference,
    this.receiptUrl,
    this.notes,
    required this.createdAt,
  });

  factory EventTransaction.fromJson(Map<String, dynamic> json, String docId) {
    return EventTransaction(
      id: docId,
      eventId: (json['eventId'] as String?) ?? '',
      type: EventTransactionType.fromString(json['type'] as String?),
      title: (json['title'] as String?) ?? '',
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 0),
      category: (json['category'] as String?) ?? 'Courses',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      paymentMode: (json['paymentMode'] as String?) ?? 'Espèces',
      recordedByUserId: (json['recordedByUserId'] as String?) ?? '',
      recordedByName: (json['recordedByName'] as String?) ?? 'Responsable',
      receiptReference: json['receiptReference'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'type': type.name,
      'title': title,
      'amountCents': amount.cents,
      'category': category,
      'date': date.toIso8601String(),
      'paymentMode': paymentMode,
      'recordedByUserId': recordedByUserId,
      'recordedByName': recordedByName,
      'receiptReference': receiptReference,
      'receiptUrl': receiptUrl,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class EventParticipant {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final DateTime registeredAt;

  const EventParticipant({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.registeredAt,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json, String docId) {
    return EventParticipant(
      id: docId,
      eventId: (json['eventId'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? 'Membre',
      registeredAt: DateTime.tryParse(json['registeredAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }
}
