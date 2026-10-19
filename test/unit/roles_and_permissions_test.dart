import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/security/roles_and_permissions.dart';
import 'package:ajra/features/auth/models/app_user.dart';

void main() {
  group('Roles and Permissions Tests', () {
    test('Admin has all permissions by default', () {
      final admin = AppUser(
        uid: 'admin-1',
        email: 'admin@ajra.org',
        displayName: 'Administrateur Test',
        role: UserRole.admin,
        permissions: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.hasPermission(AppPermissions.membershipReview), isTrue);
      expect(admin.hasPermission(AppPermissions.paymentVerify), isTrue);
      expect(admin.hasPermission(AppPermissions.financeTransactionApprove), isTrue);
      expect(admin.hasPermission(AppPermissions.usersManage), isTrue);
      expect(admin.hasPermission('any.custom.perm'), isTrue);
    });

    test('Bureau member only has assigned permissions', () {
      final bureau = AppUser(
        uid: 'bureau-1',
        email: 'tresorier@ajra.org',
        displayName: 'Trésorier Test',
        role: UserRole.bureau,
        permissions: const [
          AppPermissions.paymentVerify,
          AppPermissions.duesRecord,
          AppPermissions.financeReportView,
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(bureau.isBureau, isTrue);
      expect(bureau.canVerifyPayments, isTrue);
      expect(bureau.canRecordDues, isTrue);
      expect(bureau.canViewFinanceReports, isTrue);

      // Does NOT have review or user management permissions
      expect(bureau.canReviewMembership, isFalse);
      expect(bureau.canManageUsers, isFalse);
    });

    test('Regular member has NO privileged permissions', () {
      final member = AppUser(
        uid: 'member-1',
        email: 'membre@ajra.org',
        displayName: 'Membre Test',
        role: UserRole.member,
        permissions: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(member.isMember, isTrue);
      expect(member.canReviewMembership, isFalse);
      expect(member.canVerifyPayments, isFalse);
      expect(member.canApproveTransaction, isFalse);
      expect(member.canManageUsers, isFalse);
    });

    test('Suspended user loses ALL permissions regardless of role', () {
      final suspendedAdmin = AppUser(
        uid: 'admin-suspended',
        email: 'suspended@ajra.org',
        displayName: 'Ancien Admin',
        role: UserRole.admin,
        permissions: const ['all'],
        isSuspended: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(suspendedAdmin.isSuspended, isTrue);
      expect(suspendedAdmin.hasPermission(AppPermissions.membershipReview), isFalse);
      expect(suspendedAdmin.hasPermission(AppPermissions.paymentVerify), isFalse);
      expect(suspendedAdmin.hasPermission(AppPermissions.financeTransactionApprove), isFalse);
    });
  });
}
