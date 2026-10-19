import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';

class MemberProfile {
  final String id; // Document ID (usually matches userId or member registration ID)
  final String userId;
  final String memberNumber; // Identifiant officiel attribué ex: AJRA-2026-001
  final String lastName;
  final String firstName;
  final DateTime birthDate;
  final String residentialAddress;
  final String email;
  final String phone;
  final String? photoUrl;
  final DateTime appliedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? reviewNotes;
  final String? reviewedByUserId;
  final String? reviewedByName;
  final MembershipStatus status;

  // Données administratives sensibles (protégées)
  final String passportNumber;
  final DateTime passportIssueDate;
  final DateTime passportExpiryDate;
  final PermitType permitType;

  // Spécifique travailleur
  final String? jobTitle;
  final String? employer;

  // Spécifique étudiant
  final String? fieldOfStudy;
  final String? institution;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MemberProfile({
    required this.id,
    required this.userId,
    required this.memberNumber,
    required this.lastName,
    required this.firstName,
    required this.birthDate,
    required this.residentialAddress,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.appliedAt,
    this.approvedAt,
    this.rejectedAt,
    this.reviewNotes,
    this.reviewedByUserId,
    this.reviewedByName,
    this.status = MembershipStatus.pending,
    required this.passportNumber,
    required this.passportIssueDate,
    required this.passportExpiryDate,
    required this.permitType,
    this.jobTitle,
    this.employer,
    this.fieldOfStudy,
    this.institution,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isActive => status == MembershipStatus.active;
  bool get isPending => status == MembershipStatus.pending;
  bool get isRejected => status == MembershipStatus.rejected;
  bool get isSuspended => status == MembershipStatus.suspended;
  bool get isTerminated => status == MembershipStatus.terminated;

  bool get isPassportExpired => passportExpiryDate.isBefore(DateTime.now());

  int get daysUntilPassportExpires {
    final now = DateTime.now();
    return passportExpiryDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool isPassportExpiringSoon([int thresholdDays = AppConstants.passportAlertThresholdDays]) {
    final days = daysUntilPassportExpires;
    return days >= 0 && days <= thresholdDays;
  }

  /// Version masquée du passeport pour l'affichage non privilégié (ex: "AB****78")
  String get maskedPassportNumber {
    if (passportNumber.length <= 4) return '****';
    final start = passportNumber.substring(0, 2);
    final end = passportNumber.substring(passportNumber.length - 2);
    return '$start****$end';
  }

  factory MemberProfile.fromJson(Map<String, dynamic> json, String docId) {
    return MemberProfile(
      id: docId,
      userId: (json['userId'] as String?) ?? docId,
      memberNumber: (json['memberNumber'] as String?) ?? 'AJRA-ND',
      lastName: (json['lastName'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? '',
      birthDate: DateTime.tryParse(json['birthDate']?.toString() ?? '') ?? DateTime(2000),
      residentialAddress: (json['residentialAddress'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      appliedAt: DateTime.tryParse(json['appliedAt']?.toString() ?? '') ?? DateTime.now(),
      approvedAt: DateTime.tryParse(json['approvedAt']?.toString() ?? ''),
      rejectedAt: DateTime.tryParse(json['rejectedAt']?.toString() ?? ''),
      reviewNotes: json['reviewNotes'] as String?,
      reviewedByUserId: json['reviewedByUserId'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
      status: MembershipStatus.fromString(json['status'] as String?),
      passportNumber: (json['passportNumber'] as String?) ?? '',
      passportIssueDate:
          DateTime.tryParse(json['passportIssueDate']?.toString() ?? '') ?? DateTime(2020),
      passportExpiryDate:
          DateTime.tryParse(json['passportExpiryDate']?.toString() ?? '') ?? DateTime(2025),
      permitType: PermitType.fromString(json['permitType'] as String?),
      jobTitle: json['jobTitle'] as String?,
      employer: json['employer'] as String?,
      fieldOfStudy: json['fieldOfStudy'] as String?,
      institution: json['institution'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeSensitiveData = true}) {
    final map = <String, dynamic>{
      'userId': userId,
      'memberNumber': memberNumber,
      'lastName': lastName,
      'firstName': firstName,
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'residentialAddress': residentialAddress,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'appliedAt': appliedAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
      'reviewedByUserId': reviewedByUserId,
      'reviewedByName': reviewedByName,
      'status': status.name,
      'permitType': permitType.name,
      'jobTitle': jobTitle,
      'employer': employer,
      'fieldOfStudy': fieldOfStudy,
      'institution': institution,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };

    if (includeSensitiveData) {
      map['passportNumber'] = passportNumber;
      map['passportIssueDate'] = passportIssueDate.toIso8601String();
      map['passportExpiryDate'] = passportExpiryDate.toIso8601String();
    }

    return map;
  }

  MemberProfile copyWith({
    String? memberNumber,
    String? lastName,
    String? firstName,
    DateTime? birthDate,
    String? residentialAddress,
    String? email,
    String? phone,
    String? photoUrl,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? reviewNotes,
    String? reviewedByUserId,
    String? reviewedByName,
    MembershipStatus? status,
    String? passportNumber,
    DateTime? passportIssueDate,
    DateTime? passportExpiryDate,
    PermitType? permitType,
    String? jobTitle,
    String? employer,
    String? fieldOfStudy,
    String? institution,
    DateTime? updatedAt,
  }) {
    return MemberProfile(
      id: id,
      userId: userId,
      memberNumber: memberNumber ?? this.memberNumber,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      birthDate: birthDate ?? this.birthDate,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      appliedAt: appliedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedByUserId: reviewedByUserId ?? this.reviewedByUserId,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      status: status ?? this.status,
      passportNumber: passportNumber ?? this.passportNumber,
      passportIssueDate: passportIssueDate ?? this.passportIssueDate,
      passportExpiryDate: passportExpiryDate ?? this.passportExpiryDate,
      permitType: permitType ?? this.permitType,
      jobTitle: jobTitle ?? this.jobTitle,
      employer: employer ?? this.employer,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      institution: institution ?? this.institution,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
