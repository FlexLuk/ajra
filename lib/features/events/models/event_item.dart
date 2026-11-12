import '../../../core/utils/money.dart';

enum EventStatus {
  draft('Brouillon'),
  published('Publié'),
  inProgress('En cours'),
  completed('Terminé'),
  cancelled('Annulé');

  final String label;
  const EventStatus(this.label);

  static EventStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'published':
        return EventStatus.published;
      case 'inprogress':
      case 'in_progress':
        return EventStatus.inProgress;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      case 'draft':
      default:
        return EventStatus.draft;
    }
  }
}

class EventItem {
  final String id;
  final String title;
  final String description;
  final String type; // ex: "Assemblée", "Culturel", "Sportif", "Dîner de gala"
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String organizerUserId;
  final String organizerName;
  final Money estimatedBudget;
  final Money? fundraisingGoal;
  final Money? participationFee;
  final int expectedParticipants;
  final EventStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.organizerUserId,
    required this.organizerName,
    required this.estimatedBudget,
    this.fundraisingGoal,
    this.participationFee,
    this.expectedParticipants = 0,
    this.status = EventStatus.published,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventItem.fromJson(Map<String, dynamic> json, String docId) {
    return EventItem(
      id: docId,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'Événement',
      imageUrl: json['imageUrl'] as String?,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      location: (json['location'] as String?) ?? '',
      organizerUserId: (json['organizerUserId'] as String?) ?? '',
      organizerName: (json['organizerName'] as String?) ?? '',
      estimatedBudget: Money.fromCents((json['estimatedBudgetCents'] as num?)?.toInt() ?? 0),
      fundraisingGoal: json['fundraisingGoalCents'] != null
          ? Money.fromCents((json['fundraisingGoalCents'] as num).toInt())
          : null,
      participationFee: json['participationFeeCents'] != null
          ? Money.fromCents((json['participationFeeCents'] as num).toInt())
          : null,
      expectedParticipants: (json['expectedParticipants'] as num?)?.toInt() ?? 0,
      status: EventStatus.fromString(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'imageUrl': imageUrl,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'location': location,
      'organizerUserId': organizerUserId,
      'organizerName': organizerName,
      'estimatedBudgetCents': estimatedBudget.cents,
      'fundraisingGoalCents': fundraisingGoal?.cents,
      'participationFeeCents': participationFee?.cents,
      'expectedParticipants': expectedParticipants,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  EventItem copyWith({
    String? title,
    String? description,
    String? type,
    String? imageUrl,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? organizerUserId,
    String? organizerName,
    Money? estimatedBudget,
    Money? fundraisingGoal,
    Money? participationFee,
    int? expectedParticipants,
    EventStatus? status,
    DateTime? updatedAt,
  }) {
    return EventItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      organizerUserId: organizerUserId ?? this.organizerUserId,
      organizerName: organizerName ?? this.organizerName,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      fundraisingGoal: fundraisingGoal ?? this.fundraisingGoal,
      participationFee: participationFee ?? this.participationFee,
      expectedParticipants: expectedParticipants ?? this.expectedParticipants,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
