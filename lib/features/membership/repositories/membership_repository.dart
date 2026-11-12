import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../audit/models/audit_log_entry.dart';
import '../models/member_profile.dart';

abstract class BaseMembershipRepository {
  Stream<MemberProfile?> watchMemberProfile(String userId);
  Future<MemberProfile?> getMemberProfile(String userId);
  Future<void> submitApplication(MemberProfile profile);
  Future<bool> isEmailAlreadyUsed(String email, {String? excludeUserId});
  Stream<List<MemberProfile>> watchAllMembers({
    MembershipStatus? statusFilter,
    PermitType? permitFilter,
    String? searchQuery,
  });
  Future<void> reviewApplication({
    required String memberId,
    required String reviewerUserId,
    required String reviewerName,
    required String reviewerRole,
    required bool approve,
    String? reviewNotes,
  });
  Future<void> updateMemberStatus({
    required String memberId,
    required MembershipStatus newStatus,
    required String adminUserId,
    required String adminName,
    String? notes,
  });
  Future<void> updateMemberProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String residentialAddress,
    required String phone,
    required String passportNumber,
    required DateTime passportIssueDate,
    required DateTime passportExpiryDate,
    required PermitType permitType,
    String? jobTitle,
    String? employer,
    String? fieldOfStudy,
    String? institution,
  });
  Future<List<MemberProfile>> getExpiringPassports({int days = AppConstants.passportAlertThresholdDays});
}

class FirestoreMembershipRepository implements BaseMembershipRepository {
  final FirebaseFirestore _firestore;

  FirestoreMembershipRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _membersCol =>
      _firestore.collection(AppConstants.colMembers);

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _firestore.collection(AppConstants.colAuditLogs);

  @override
  Future<bool> isEmailAlreadyUsed(String email, {String? excludeUserId}) async {
    try {
      final normalized = email.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      final snapshot = await _membersCol.get();
      for (final doc in snapshot.docs) {
        if (excludeUserId != null && doc.id == excludeUserId) continue;
        final data = doc.data();
        final docEmail = (data['email'] as String?)?.trim().toLowerCase() ?? '';
        if (docEmail == normalized) {
          return true;
        }
      }
      return false;
    } catch (_) {
      // Les adhérents non encore validés n'ont pas accès en lecture à toute la collection members (sécurité/confidentialité)
      return false;
    }
  }

  @override
  Stream<MemberProfile?> watchMemberProfile(String userId) {
    return _membersCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MemberProfile.fromJson(doc.data()!, doc.id);
    });
  }

  @override
  Future<MemberProfile?> getMemberProfile(String userId) async {
    final doc = await _membersCol.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return MemberProfile.fromJson(doc.data()!, doc.id);
  }

  @override
  Future<void> submitApplication(MemberProfile profile) async {
    final docRef = _membersCol.doc(profile.userId);
    await docRef.set(profile.toJson(includeSensitiveData: true), SetOptions(merge: true));

    // Audit Log (tolérant aux droits)
    try {
      final audit = AuditLogEntry(
        id: _auditCol.doc().id,
        userId: profile.userId,
        userName: profile.fullName,
        userRole: UserRole.member.code,
        action: 'membership.applied',
        entityType: 'membership',
        entityId: profile.userId,
        details: {
          'memberNumber': profile.memberNumber,
          'permitType': profile.permitType.name,
        },
        timestamp: DateTime.now(),
      );
      await _auditCol.doc(audit.id).set(audit.toJson());
    } catch (_) {}
  }

  @override
  Stream<List<MemberProfile>> watchAllMembers({
    MembershipStatus? statusFilter,
    PermitType? permitFilter,
    String? searchQuery,
  }) {
    return _membersCol.snapshots().map((snapshot) {
      var members = snapshot.docs
          .map((doc) => MemberProfile.fromJson(doc.data(), doc.id))
          .toList();

      if (statusFilter != null) {
        members = members.where((m) => m.status == statusFilter).toList();
      }
      if (permitFilter != null) {
        members = members.where((m) => m.permitType == permitFilter).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        members = members.where((m) {
          return m.fullName.toLowerCase().contains(q) ||
              m.email.toLowerCase().contains(q) ||
              m.memberNumber.toLowerCase().contains(q) ||
              m.phone.contains(q);
        }).toList();
      }

      members.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return members;
    });
  }

  @override
  Future<void> reviewApplication({
    required String memberId,
    required String reviewerUserId,
    required String reviewerName,
    required String reviewerRole,
    required bool approve,
    String? reviewNotes,
  }) async {
    // Un membre du bureau non-admin ne peut pas approuver sa propre adhésion. L'administrateur peut tout valider.
    if (memberId == reviewerUserId && reviewerRole != UserRole.admin.code) {
      throw Exception('Un membre du bureau ne peut pas statuer sur sa propre adhésion. Seul l\'administrateur possède cette prérogative.');
    }

    final newStatus = approve ? MembershipStatus.active : MembershipStatus.rejected;
    final now = DateTime.now();

    final updateData = <String, dynamic>{
      'status': newStatus.name,
      'reviewedByUserId': reviewerUserId,
      'reviewedByName': reviewerName,
      'reviewNotes': reviewNotes,
      'updatedAt': now.toIso8601String(),
    };

    if (approve) {
      updateData['approvedAt'] = now.toIso8601String();
    } else {
      updateData['rejectedAt'] = now.toIso8601String();
    }

    await _membersCol.doc(memberId).update(updateData);

    // Audit log
    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: reviewerUserId,
      userName: reviewerName,
      userRole: reviewerRole,
      action: approve ? 'membership.approved' : 'membership.rejected',
      entityType: 'membership',
      entityId: memberId,
      details: {
        'status': newStatus.name,
        'notes': reviewNotes ?? '',
      },
      timestamp: now,
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> updateMemberStatus({
    required String memberId,
    required MembershipStatus newStatus,
    required String adminUserId,
    required String adminName,
    String? notes,
  }) async {
    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'status': newStatus.name,
      'reviewedByUserId': adminUserId,
      'reviewedByName': adminName,
      'reviewNotes': notes,
      'updatedAt': now.toIso8601String(),
    };

    if (newStatus == MembershipStatus.active) {
      updateData['approvedAt'] = now.toIso8601String();
    } else if (newStatus == MembershipStatus.rejected) {
      updateData['rejectedAt'] = now.toIso8601String();
    }

    await _membersCol.doc(memberId).update(updateData);

    final audit = AuditLogEntry(
      id: _auditCol.doc().id,
      userId: adminUserId,
      userName: adminName,
      userRole: UserRole.admin.code,
      action: 'membership.status_updated',
      entityType: 'membership',
      entityId: memberId,
      details: {
        'newStatus': newStatus.name,
        'notes': notes ?? '',
      },
      timestamp: now,
    );
    await _auditCol.doc(audit.id).set(audit.toJson());
  }

  @override
  Future<void> updateMemberProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String residentialAddress,
    required String phone,
    required String passportNumber,
    required DateTime passportIssueDate,
    required DateTime passportExpiryDate,
    required PermitType permitType,
    String? jobTitle,
    String? employer,
    String? fieldOfStudy,
    String? institution,
  }) async {
    final now = DateTime.now();
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

    final updateData = <String, dynamic>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'residentialAddress': residentialAddress.trim(),
      'phone': phone.trim(),
      'passportNumber': passportNumber.trim(),
      'passportIssueDate': passportIssueDate.toIso8601String(),
      'passportExpiryDate': passportExpiryDate.toIso8601String(),
      'permitType': permitType.name,
      'jobTitle': permitType == PermitType.worker ? jobTitle?.trim() : null,
      'employer': permitType == PermitType.worker ? employer?.trim() : null,
      'fieldOfStudy': permitType == PermitType.student ? fieldOfStudy?.trim() : null,
      'institution': permitType == PermitType.student ? institution?.trim() : null,
      'updatedAt': now.toIso8601String(),
    };

    await _membersCol.doc(userId).update(updateData);

    // Synchroniser le nom d'affichage sur le compte utilisateur
    try {
      await _firestore.collection(AppConstants.colUsers).doc(userId).update({
        'displayName': fullName,
        'updatedAt': now.toIso8601String(),
      });
    } catch (_) {}

    // Audit log
    try {
      final audit = AuditLogEntry(
        id: _auditCol.doc().id,
        userId: userId,
        userName: fullName,
        userRole: UserRole.member.code,
        action: 'membership.profile_updated',
        entityType: 'membership',
        entityId: userId,
        details: {
          'phone': phone.trim(),
          'permitType': permitType.name,
        },
        timestamp: now,
      );
      await _auditCol.doc(audit.id).set(audit.toJson());
    } catch (_) {}
  }

  @override
  Future<List<MemberProfile>> getExpiringPassports({
    int days = AppConstants.passportAlertThresholdDays,
  }) async {
    final now = DateTime.now();
    final thresholdDate = now.add(Duration(days: days));

    final snapshot = await _membersCol
        .where('status', isEqualTo: MembershipStatus.active.name)
        .get();

    final members = snapshot.docs
        .map((doc) => MemberProfile.fromJson(doc.data(), doc.id))
        .where((m) =>
            m.passportExpiryDate.isBefore(thresholdDate) ||
            m.passportExpiryDate.isBefore(now))
        .toList();

    return members;
  }
}
