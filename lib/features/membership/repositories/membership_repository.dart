import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../audit/models/audit_log_entry.dart';
import '../models/member_profile.dart';

abstract class BaseMembershipRepository {
  Stream<MemberProfile?> watchMemberProfile(String userId);
  Future<MemberProfile?> getMemberProfile(String userId);
  Future<void> submitApplication(MemberProfile profile);
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

    // Audit Log
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
  }

  @override
  Stream<List<MemberProfile>> watchAllMembers({
    MembershipStatus? statusFilter,
    PermitType? permitFilter,
    String? searchQuery,
  }) {
    Query<Map<String, dynamic>> query = _membersCol.orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }
    if (permitFilter != null) {
      query = query.where('permitType', isEqualTo: permitFilter.name);
    }

    return query.snapshots().map((snapshot) {
      var members = snapshot.docs
          .map((doc) => MemberProfile.fromJson(doc.data(), doc.id))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        members = members.where((m) {
          return m.fullName.toLowerCase().contains(q) ||
              m.email.toLowerCase().contains(q) ||
              m.memberNumber.toLowerCase().contains(q) ||
              m.phone.contains(q);
        }).toList();
      }

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
    // Un membre ne peut jamais approuver sa propre adhésion
    if (memberId == reviewerUserId) {
      throw Exception('Un membre ne peut jamais approuver ou statuer sur sa propre adhésion.');
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
