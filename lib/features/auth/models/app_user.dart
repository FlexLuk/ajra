import '../../../core/security/roles_and_permissions.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final UserRole role;
  final List<String> permissions;
  final bool isSuspended;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.role = UserRole.member,
    this.permissions = const [],
    this.isSuspended = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isBureau => role == UserRole.bureau;
  bool get isMember => role == UserRole.member;

  /// Vérifie si l'utilisateur possède une permission spécifique.
  /// L'administrateur possède toutes les permissions par défaut.
  /// Un compte suspendu n'a aucune permission active.
  bool hasPermission(String permission) {
    if (isSuspended) return false;
    if (isAdmin) return true;
    return permissions.contains(permission);
  }

  bool get canReviewMembership => hasPermission(AppPermissions.membershipReview);
  bool get canManageMembership => hasPermission(AppPermissions.membershipManage);
  bool get canVerifyPayments => hasPermission(AppPermissions.paymentVerify);
  bool get canRecordDues => hasPermission(AppPermissions.duesRecord);
  bool get canManageDues => hasPermission(AppPermissions.duesManage);
  bool get canCreateTransaction => hasPermission(AppPermissions.financeTransactionCreate);
  bool get canApproveTransaction => hasPermission(AppPermissions.financeTransactionApprove);
  bool get canViewFinanceReports => hasPermission(AppPermissions.financeReportView);
  bool get canManageEvents => hasPermission(AppPermissions.eventManage);
  bool get canManageFundraising => hasPermission(AppPermissions.fundraisingManage);
  bool get canPublishPosts => hasPermission(AppPermissions.postPublish);
  bool get canManageUsers => hasPermission(AppPermissions.usersManage);
  bool get canViewAudit => hasPermission(AppPermissions.auditView);

  factory AppUser.fromJson(Map<String, dynamic> json, String uid) {
    return AppUser(
      uid: uid,
      email: (json['email'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      role: UserRole.fromCode(json['role'] as String?),
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isSuspended: (json['isSuspended'] as bool?) ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.code,
      'permissions': permissions,
      'isSuspended': isSuspended,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    UserRole? role,
    List<String>? permissions,
    bool? isSuspended,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isSuspended: isSuspended ?? this.isSuspended,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
